#!/usr/bin/env python3
"""64px個別フレームから離れた孤立成分を除去し、残留ごみを最終検査する。"""

from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path
from typing import Any

from PIL import Image


DEFAULTS = {
    "enabled": True,
    "alpha_threshold": 8,
    "min_component_area": 2,
    "max_component_gap": 8,
    "max_auto_remove_area": 12,
    "remove_above_primary": True,
    "max_above_primary_area": 32,
    "max_removed_pixels": 64,
}


def cleanup_config(spec: dict[str, Any] | None) -> dict[str, Any]:
    value = dict(DEFAULTS)
    if isinstance(spec, dict):
        configured = spec.get("artifact_cleanup")
        if isinstance(configured, dict):
            value.update(configured)
        # エフェクトや飛翔体の分離粒子は表現要素であり、人物用cleanupの対象ではない。
        # 必要な場合だけartifact_cleanup.enabled=trueを明示して有効にする。
        elif spec.get("profile") in ("effect", "projectile"):
            value["enabled"] = False
    for key in DEFAULTS:
        if not isinstance(value[key], (int, bool)) or isinstance(value[key], bool) != isinstance(DEFAULTS[key], bool):
            raise ValueError(f"artifact_cleanup.{key} has an invalid value")
    if value["alpha_threshold"] < 0 or value["alpha_threshold"] > 255:
        raise ValueError("artifact_cleanup.alpha_threshold must be 0..255")
    for key in ("min_component_area", "max_component_gap", "max_auto_remove_area", "max_above_primary_area", "max_removed_pixels"):
        if value[key] < 0:
            raise ValueError(f"artifact_cleanup.{key} must be non-negative")
    return value


def alpha_components(image: Image.Image, threshold: int) -> list[dict[str, Any]]:
    alpha = image.convert("RGBA").getchannel("A")
    width, height = image.size
    pixels = alpha.load()
    seen: set[tuple[int, int]] = set()
    components: list[dict[str, Any]] = []
    for y in range(height):
        for x in range(width):
            if (x, y) in seen or pixels[x, y] < threshold:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            seen.add((x, y))
            points: list[tuple[int, int]] = []
            while queue:
                px, py = queue.popleft()
                points.append((px, py))
                for ny in range(max(0, py - 1), min(height, py + 2)):
                    for nx in range(max(0, px - 1), min(width, px + 2)):
                        if (nx, ny) in seen or pixels[nx, ny] < threshold:
                            continue
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            xs = [point[0] for point in points]
            ys = [point[1] for point in points]
            components.append({"points": points, "area": len(points), "bbox": [min(xs), min(ys), max(xs) + 1, max(ys) + 1]})
    components.sort(key=lambda item: item["area"], reverse=True)
    return components


def rectangle_gap(first: list[int], second: list[int]) -> int:
    dx = max(first[0] - second[2], second[0] - first[2], 0)
    dy = max(first[1] - second[3], second[1] - first[3], 0)
    return max(dx, dy)


def analyze_artifacts(image: Image.Image, config: dict[str, Any] | None = None) -> dict[str, Any]:
    settings = dict(DEFAULTS) if config is None else config
    if not settings.get("enabled", True):
        return {"status": "disabled", "components": [], "candidates": [], "removed_pixels": 0}
    threshold = int(settings["alpha_threshold"])
    components = alpha_components(image, threshold)
    if not components:
        return {"status": "fail", "components": [], "candidates": [], "removed_pixels": 0, "errors": ["empty alpha after threshold"]}

    primary = components[0]
    component_reports: list[dict[str, Any]] = []
    candidates: list[dict[str, Any]] = []
    unsafe: list[dict[str, Any]] = []
    for index, component in enumerate(components):
        gap = 0 if index == 0 else rectangle_gap(primary["bbox"], component["bbox"])
        is_tiny = index != 0 and component["area"] < int(settings["min_component_area"])
        is_far = index != 0 and gap > int(settings["max_component_gap"])
        action = "keep"
        is_above_primary = (
            index != 0
            and bool(settings.get("remove_above_primary", True))
            and component["bbox"][3] <= primary["bbox"][1]
        )
        reasons = []
        if is_tiny and gap > 0:
            reasons.append("tiny")
        if is_far:
            reasons.append("far")
        if is_above_primary:
            reasons.append("above_primary")
        can_remove = (
            (is_tiny and gap > 0)
            or (is_above_primary and component["area"] <= int(settings["max_above_primary_area"]))
            or (is_far and component["area"] <= int(settings["max_auto_remove_area"]))
        )
        if reasons:
            if not can_remove:
                action = "review_required"
                unsafe.append({"index": index, "area": component["area"], "bbox": component["bbox"], "gap": gap, "reasons": reasons})
            else:
                action = "remove"
                candidates.append({"index": index, "area": component["area"], "bbox": component["bbox"], "gap": gap, "reasons": reasons})
        component_reports.append({"index": index, "area": component["area"], "bbox": component["bbox"], "gap": gap, "action": action, "reasons": reasons})
    removed_pixels = sum(item["area"] for item in candidates)
    errors: list[str] = []
    if unsafe:
        errors.append(f"{len(unsafe)} far component(s) exceed max_auto_remove_area")
    if removed_pixels > int(settings["max_removed_pixels"]):
        errors.append(f"removal would affect {removed_pixels} pixels, maximum is {settings['max_removed_pixels']}")
    return {
        "status": "pass" if not errors else "fail",
        "primary_component": {"area": primary["area"], "bbox": primary["bbox"]},
        "components": component_reports,
        "candidates": candidates,
        "unsafe_components": unsafe,
        "removed_pixels": removed_pixels,
        "errors": errors,
    }


def remove_candidates(image: Image.Image, analysis: dict[str, Any], threshold: int) -> Image.Image:
    result = image.convert("RGBA").copy()
    alpha = result.getchannel("A")
    components = alpha_components(result, threshold)
    remove_indices = {item["index"] for item in analysis.get("candidates", [])}
    alpha_pixels = alpha.load()
    for index in remove_indices:
        for x, y in components[index]["points"]:
            alpha_pixels[x, y] = 0
    result.putalpha(alpha)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if not args.check_only and args.output is None:
        parser.error("output is required unless --check-only is used")
    spec = json.loads(args.spec.read_text(encoding="utf-8")) if args.spec else {}
    settings = cleanup_config(spec)
    image = Image.open(args.input).convert("RGBA")
    analysis = analyze_artifacts(image, settings)
    analysis.update({"input": str(args.input), "threshold": settings["alpha_threshold"], "config": settings})
    if args.check_only and analysis.get("candidates"):
        analysis["status"] = "fail"
        analysis.setdefault("errors", []).append("artifact candidates remain; run cleanup before final check")
    if not args.check_only and analysis["status"] == "pass":
        cleaned = remove_candidates(image, analysis, int(settings["alpha_threshold"]))
        final_analysis = analyze_artifacts(cleaned, settings)
        analysis["post_cleanup"] = final_analysis
        if final_analysis["status"] != "pass" or final_analysis.get("candidates"):
            analysis["status"] = "fail"
            analysis.setdefault("errors", []).append("artifact candidates remain after cleanup")
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            cleaned.save(args.output)
            analysis["output"] = str(args.output)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(analysis, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": analysis["status"], "candidates": len(analysis.get("candidates", [])), "removed_pixels": analysis.get("removed_pixels", 0)}, ensure_ascii=False))
    return 0 if analysis["status"] in ("pass", "disabled") else 1


if __name__ == "__main__":
    raise SystemExit(main())
