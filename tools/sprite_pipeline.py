"""汎用スプライト制作仕様の読込、legacy変換、配置解決を共有する。"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class SpriteSpecError(ValueError):
    """制作仕様が不正なときに送出する例外。"""


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise SpriteSpecError(f"cannot read {label}: {path}") from error
    except json.JSONDecodeError as error:
        raise SpriteSpecError(f"invalid JSON in {label}: {path}: {error.msg}") from error
    if not isinstance(value, dict):
        raise SpriteSpecError(f"{label} must be a JSON object")
    return value


def string_list(value: Any, name: str) -> list[str]:
    if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item for item in value):
        raise SpriteSpecError(f"{name} must be a non-empty array of strings")
    if len(set(value)) != len(value):
        raise SpriteSpecError(f"{name} must not contain duplicates")
    return value


def positive_int(value: Any, name: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        raise SpriteSpecError(f"{name} must be a positive integer")
    return value


def nonnegative_int(value: Any, name: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise SpriteSpecError(f"{name} must be a non-negative integer")
    return value


def number(value: Any, name: str) -> float:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise SpriteSpecError(f"{name} must be a number")
    return float(value)


def point(value: Any, name: str) -> tuple[float, float] | None:
    if value is None:
        return None
    if isinstance(value, list) and len(value) == 2:
        return number(value[0], f"{name}[0]"), number(value[1], f"{name}[1]")
    if isinstance(value, dict) and "x" in value and "y" in value:
        return number(value["x"], f"{name}.x"), number(value["y"], f"{name}.y")
    raise SpriteSpecError(f"{name} must be [x, y] or {{x, y}}")


def _canvas(raw: dict[str, Any]) -> dict[str, int]:
    value = raw.get("canvas")
    if not isinstance(value, dict):
        raise SpriteSpecError("spec.canvas must be an object")
    return {"width": positive_int(value.get("width"), "spec.canvas.width"), "height": positive_int(value.get("height"), "spec.canvas.height")}


def _grid_layout(value: Any, canvas: dict[str, int], prefix: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise SpriteSpecError(f"{prefix} must be an object")
    cell = value.get("cell_size")
    if not isinstance(cell, dict):
        raise SpriteSpecError(f"{prefix}.cell_size must be an object")
    width = positive_int(cell.get("width"), f"{prefix}.cell_size.width")
    height = positive_int(cell.get("height"), f"{prefix}.cell_size.height")
    columns = string_list(value.get("columns"), f"{prefix}.columns")
    rows = string_list(value.get("rows"), f"{prefix}.rows")
    if canvas != {"width": width * len(columns), "height": height * len(rows)}:
        raise SpriteSpecError("spec canvas size must equal grid cell_size multiplied by columns and rows")
    return {"type": "grid", "cell_size": {"width": width, "height": height}, "columns": columns, "rows": rows}


def _anchor(raw: dict[str, Any], layout: dict[str, Any], legacy: bool) -> dict[str, Any]:
    value = raw.get("anchor")
    if value is None and "foot_anchor" in raw:
        foot_anchor = raw["foot_anchor"]
        if not isinstance(foot_anchor, dict):
            raise SpriteSpecError("legacy spec.foot_anchor must be an object")
        value = {"type": "feet", **foot_anchor}
    if value is None:
        return {"type": "feet" if legacy else "none"}
    if not isinstance(value, dict):
        raise SpriteSpecError("spec.anchor must be an object")
    anchor_type = value.get("type", "feet")
    if anchor_type not in ("feet", "center", "none"):
        raise SpriteSpecError("spec.anchor.type must be feet, center, or none")
    result: dict[str, Any] = {"type": anchor_type}
    if "x" in value or "y" in value:
        if "x" not in value or "y" not in value:
            raise SpriteSpecError("spec.anchor requires both x and y when either is set")
        result["x"] = number(value["x"], "spec.anchor.x")
        result["y"] = number(value["y"], "spec.anchor.y")
    elif legacy and anchor_type == "feet":
        raise SpriteSpecError("legacy spec.foot_anchor requires x and y")
    return result


def parse_asset_spec(raw: dict[str, Any]) -> dict[str, Any]:
    """asset spec v2または従来のcolumns/rows形式を正規化する。"""
    canvas = _canvas(raw)
    legacy = "layout" not in raw
    if legacy:
        layout = _grid_layout({"cell_size": raw.get("cell_size"), "columns": raw.get("columns"), "rows": raw.get("rows")}, canvas, "legacy spec")
    else:
        layout_raw = raw.get("layout")
        if not isinstance(layout_raw, dict):
            raise SpriteSpecError("spec.layout must be an object")
        layout_type = layout_raw.get("type")
        if layout_type == "grid":
            layout = _grid_layout(layout_raw, canvas, "spec.layout")
        elif layout_type == "atlas":
            layout = {"type": "atlas"}
        else:
            raise SpriteSpecError("spec.layout.type must be grid or atlas")
    asset_id = raw.get("asset_id")
    if not isinstance(asset_id, str) or not asset_id:
        raise SpriteSpecError("spec.asset_id must be a non-empty string")
    profile = raw.get("profile", "character" if legacy else "effect")
    if profile not in ("character", "weapon_attack", "projectile", "effect"):
        raise SpriteSpecError("spec.profile must be character, weapon_attack, projectile, or effect")
    normalization = raw.get("normalization", {})
    if not isinstance(normalization, dict):
        raise SpriteSpecError("spec.normalization must be an object")
    alpha_threshold = normalization.get("alpha_bbox_threshold", 8)
    if not isinstance(alpha_threshold, int) or not 0 <= alpha_threshold <= 255:
        raise SpriteSpecError("normalization.alpha_bbox_threshold must be 0..255")
    return {
        "asset_id": asset_id,
        "schema_version": raw.get("schema_version", 1 if legacy else 2),
        "legacy": legacy,
        "canvas": canvas,
        "layout": layout,
        "profile": profile,
        "anchor": _anchor(raw, layout, legacy),
        "normalization": normalization,
        "palette": raw.get("palette"),
        "artifact_cleanup": raw.get("artifact_cleanup"),
        "raw": raw,
    }


def _rect_from_placement(value: Any, asset: dict[str, Any], name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise SpriteSpecError(f"{name}.placement must be an object")
    layout = asset["layout"]
    if layout["type"] == "grid":
        column = value.get("column")
        row = value.get("row")
        if not isinstance(column, str) or column not in layout["columns"]:
            raise SpriteSpecError(f"{name}.placement.column must name a spec.layout column")
        if not isinstance(row, str) or row not in layout["rows"]:
            raise SpriteSpecError(f"{name}.placement.row must name a spec.layout row")
        cell = layout["cell_size"]
        return {
            "x": layout["columns"].index(column) * cell["width"],
            "y": layout["rows"].index(row) * cell["height"],
            "width": cell["width"],
            "height": cell["height"],
            "column": column,
            "row": row,
        }
    try:
        rect = {
            "x": nonnegative_int(value.get("x"), f"{name}.placement.x"),
            "y": nonnegative_int(value.get("y"), f"{name}.placement.y"),
            "width": positive_int(value.get("width"), f"{name}.placement.width"),
            "height": positive_int(value.get("height"), f"{name}.placement.height"),
        }
    except SpriteSpecError:
        raise
    if rect["x"] < 0 or rect["y"] < 0 or rect["x"] + rect["width"] > asset["canvas"]["width"] or rect["y"] + rect["height"] > asset["canvas"]["height"]:
        raise SpriteSpecError(f"{name}.placement must fit inside spec.canvas")
    return rect


def _frame(raw: Any, asset: dict[str, Any], clip_id: str, variant_id: str, index: int) -> dict[str, Any]:
    name = f"animation clip {clip_id} variant {variant_id} frame {index}"
    if not isinstance(raw, dict):
        raise SpriteSpecError(f"{name} must be an object")
    frame_id = raw.get("id")
    if not isinstance(frame_id, str) or not frame_id:
        raise SpriteSpecError(f"{name}.id must be a non-empty string")
    placement = _rect_from_placement(raw.get("placement", raw.get("slot")), asset, name)
    duration = raw.get("duration")
    if duration is not None and (not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0):
        raise SpriteSpecError(f"{name}.duration must be greater than zero")
    events = raw.get("events", [])
    if not isinstance(events, list) or any(not isinstance(event, str) or not event for event in events):
        raise SpriteSpecError(f"{name}.events must be an array of non-empty strings")
    return {
        "id": frame_id,
        "clip": clip_id,
        "variant": variant_id,
        "placement": placement,
        "duration": float(duration) if duration is not None else None,
        "events": events,
        "root": point(raw.get("root", raw.get("root_anchor")), f"{name}.root"),
        "contact_point": point(raw.get("contact_point"), f"{name}.contact_point"),
        "ground_y": number(raw["ground_y"], f"{name}.ground_y") if "ground_y" in raw else None,
        "raw": raw,
    }


def _check_unique(frames: list[dict[str, Any]], legacy: bool) -> None:
    ids: set[str] = set()
    placements: set[tuple[int, int, int, int]] = set()
    for frame in frames:
        if frame["id"] in ids:
            raise SpriteSpecError(f"duplicate animation frame id: {frame['id']}")
        ids.add(frame["id"])
        rect = frame["placement"]
        key = (rect["x"], rect["y"], rect["width"], rect["height"])
        if key in placements:
            if legacy:
                raise SpriteSpecError(f"duplicate motion position: {rect.get('column')}/{rect.get('row')}")
            raise SpriteSpecError(f"duplicate animation placement: {frame['id']}")
        placements.add(key)
    for first_index, first in enumerate(frames):
        left = first["placement"]
        for second in frames[first_index + 1:]:
            right = second["placement"]
            if max(left["x"], right["x"]) < min(left["x"] + left["width"], right["x"] + right["width"]) and max(left["y"], right["y"]) < min(left["y"] + left["height"], right["y"] + right["height"]):
                raise SpriteSpecError(f"overlapping animation placements: {first['id']} and {second['id']}")


def _legacy_animation(raw: dict[str, Any], asset: dict[str, Any]) -> dict[str, Any]:
    source_frames = raw.get("frames")
    if not isinstance(source_frames, list) or not source_frames:
        raise SpriteSpecError("motion.frames must be a non-empty array")
    layout = asset["layout"]
    if layout["type"] != "grid":
        raise SpriteSpecError("legacy motion requires a grid asset spec")
    by_clip: dict[str, dict[str, list[dict[str, Any]]]] = {"idle": {}, "walk": {}}
    all_frames: list[dict[str, Any]] = []
    seen_positions: set[tuple[str, str]] = set()
    seen_ids: set[str] = set()
    for index, raw_frame in enumerate(source_frames):
        if not isinstance(raw_frame, dict):
            raise SpriteSpecError("each motion frame must be an object")
        frame_id, direction, phase = raw_frame.get("id"), raw_frame.get("direction"), raw_frame.get("phase")
        if not all(isinstance(value, str) and value for value in (frame_id, direction, phase)):
            raise SpriteSpecError(f"motion frame requires non-empty id, direction, and phase: {raw_frame!r}")
        if frame_id in seen_ids:
            raise SpriteSpecError(f"duplicate motion frame id: {frame_id}")
        if direction not in layout["columns"]:
            raise SpriteSpecError(f"motion frame {frame_id} has unknown direction: {direction}")
        if phase not in layout["rows"]:
            raise SpriteSpecError(f"motion frame {frame_id} has unknown phase: {phase}")
        if (direction, phase) in seen_positions:
            raise SpriteSpecError(f"duplicate motion position: {direction}/{phase}")
        seen_ids.add(frame_id)
        seen_positions.add((direction, phase))
        clip_id = "idle" if phase == "idle" else "walk"
        frame = _frame({**raw_frame, "placement": {"column": direction, "row": phase}}, asset, clip_id, direction, index)
        by_clip[clip_id].setdefault(direction, []).append(frame)
        all_frames.append(frame)
    clips = []
    for clip_id in ("idle", "walk"):
        variants = [{"id": direction, "labels": {"direction": direction}, "frames": by_clip[clip_id].get(direction, [])} for direction in layout["columns"]]
        clips.append({"id": clip_id, "loop": clip_id == "walk", "fps": 8.0, "variants": variants})
    return {"asset_id": raw.get("asset_id", asset["asset_id"]), "legacy": True, "clips": clips, "frames": all_frames}


def parse_animation_spec(raw: dict[str, Any], asset: dict[str, Any]) -> dict[str, Any]:
    """animation spec v2または従来motion specを正規化する。"""
    if "clips" not in raw:
        return _legacy_animation(raw, asset)
    asset_id = raw.get("asset_id")
    if asset_id is not None and asset_id != asset["asset_id"]:
        raise SpriteSpecError("animation.asset_id must match spec.asset_id")
    raw_clips = raw.get("clips")
    if not isinstance(raw_clips, list) or not raw_clips:
        raise SpriteSpecError("animation.clips must be a non-empty array")
    clips: list[dict[str, Any]] = []
    all_frames: list[dict[str, Any]] = []
    clip_ids: set[str] = set()
    for clip_index, raw_clip in enumerate(raw_clips):
        if not isinstance(raw_clip, dict):
            raise SpriteSpecError(f"animation.clips[{clip_index}] must be an object")
        clip_id = raw_clip.get("id")
        if not isinstance(clip_id, str) or not clip_id:
            raise SpriteSpecError(f"animation.clips[{clip_index}].id must be a non-empty string")
        if clip_id in clip_ids:
            raise SpriteSpecError(f"duplicate animation clip id: {clip_id}")
        clip_ids.add(clip_id)
        fps = raw_clip.get("fps", 8)
        if not isinstance(fps, (int, float)) or isinstance(fps, bool) or fps <= 0:
            raise SpriteSpecError(f"animation clip {clip_id}.fps must be greater than zero")
        if not isinstance(raw_clip.get("loop", False), bool):
            raise SpriteSpecError(f"animation clip {clip_id}.loop must be boolean")
        raw_variants = raw_clip.get("variants")
        if raw_variants is None:
            raw_variants = [{"id": "default", "frames": raw_clip.get("frames")}]
        if not isinstance(raw_variants, list) or not raw_variants:
            raise SpriteSpecError(f"animation clip {clip_id}.variants must be a non-empty array")
        variants: list[dict[str, Any]] = []
        variant_ids: set[str] = set()
        for variant_index, raw_variant in enumerate(raw_variants):
            if not isinstance(raw_variant, dict):
                raise SpriteSpecError(f"animation clip {clip_id}.variants[{variant_index}] must be an object")
            variant_id = raw_variant.get("id", "default")
            if not isinstance(variant_id, str) or not variant_id:
                raise SpriteSpecError(f"animation clip {clip_id} variant id must be a non-empty string")
            if variant_id in variant_ids:
                raise SpriteSpecError(f"duplicate animation variant id: {clip_id}/{variant_id}")
            variant_ids.add(variant_id)
            labels = raw_variant.get("labels", {})
            if not isinstance(labels, dict) or any(not isinstance(key, str) or not isinstance(value, str) for key, value in labels.items()):
                raise SpriteSpecError(f"animation clip {clip_id} variant {variant_id}.labels must be string pairs")
            raw_frames = raw_variant.get("frames")
            if not isinstance(raw_frames, list) or not raw_frames:
                raise SpriteSpecError(f"animation clip {clip_id} variant {variant_id}.frames must be a non-empty array")
            frames = [_frame(frame, asset, clip_id, variant_id, frame_index) for frame_index, frame in enumerate(raw_frames)]
            variants.append({"id": variant_id, "labels": labels, "frames": frames})
            all_frames.extend(frames)
        clips.append({"id": clip_id, "loop": raw_clip.get("loop", False), "fps": float(fps), "variants": variants})
    _check_unique(all_frames, legacy=False)
    return {"asset_id": asset["asset_id"], "legacy": False, "clips": clips, "frames": all_frames}


def load_pipeline(spec_path: Path, animation_path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    asset = parse_asset_spec(load_json(spec_path, "asset spec"))
    animation = parse_animation_spec(load_json(animation_path, "animation spec"), asset)
    return asset, animation


def target_anchor(asset: dict[str, Any], placement: dict[str, Any]) -> tuple[float, float] | None:
    anchor = asset["anchor"]
    anchor_type = anchor["type"]
    if anchor_type == "none":
        return None
    if "x" in anchor:
        return float(anchor["x"]), float(anchor["y"])
    if anchor_type == "center":
        return (placement["width"] - 1) / 2, (placement["height"] - 1) / 2
    return (placement["width"] - 1) / 2, placement["height"] - 1


def alpha_threshold(asset: dict[str, Any]) -> int:
    return int(asset["normalization"].get("alpha_bbox_threshold", 8))


def expected_grid_positions(asset: dict[str, Any]) -> set[tuple[str, str]]:
    layout = asset["layout"]
    if layout["type"] != "grid":
        return set()
    return {(column, row) for column in layout["columns"] for row in layout["rows"]}
