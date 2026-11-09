#!/usr/bin/env python3
"""Importar transcripción completa de un video como material consultable por Codex.

Uso: python .../ingest_youtube.py URL [--frames] [--device cpu|cuda]
Requiere youtube-transcript-api; fallback ASR necesita yt-dlp, ffmpeg y faster-whisper.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import parse_qs, urlparse


def video_id_from_url(value: str) -> str:
    value = value.strip()
    if re.fullmatch(r"[A-Za-z0-9_-]{11}", value):
        return value
    p = urlparse(value)
    host = (p.hostname or "").lower()
    vid = None
    if host in {"youtu.be", "www.youtu.be"}:
        vid = p.path.strip("/").split("/")[0]
    elif host in {"youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"}:
        if p.path == "/watch":
            vid = parse_qs(p.query).get("v", [None])[0]
        elif p.path.startswith(("/shorts/", "/live/", "/embed/")):
            vid = p.path.split("/")[2]
    if not vid or not re.fullmatch(r"[A-Za-z0-9_-]{11}", vid):
        raise ValueError("URL de YouTube no compatible o ID de video inválido")
    return vid


def clock(sec: float) -> str:
    s = max(0, int(sec))
    return f"{s//3600:02d}:{(s//60)%60:02d}:{s%60:02d}"


def get_captions(video_id: str, langs: list[str]) -> tuple[list[dict], str, str]:
    from youtube_transcript_api import YouTubeTranscriptApi
    api = YouTubeTranscriptApi()
    available = api.list(video_id)
    transcript = available.find_transcript(langs)
    data = transcript.fetch().to_raw_data()
    entries = [{"start": float(x["start"]), "duration": float(x["duration"]), "text": str(x["text"])} for x in data]
    return entries, transcript.language_code, "youtube-captions-generated" if transcript.is_generated else "youtube-captions-manual"


def run(cmd: list[str]) -> None:
    print("Ejecutando:", " ".join(cmd[:5]), "...", flush=True)
    subprocess.run(cmd, check=True)


def get_asr(url: str, work: Path, model_name: str, device: str) -> tuple[list[dict], str, str]:
    if not shutil.which("ffmpeg"):
        raise RuntimeError("Falta FFmpeg en PATH; necesario para audio ASR")
    try:
        from faster_whisper import WhisperModel
    except ImportError as e:
        raise RuntimeError("Falta faster-whisper: ejecutar pip install faster-whisper") from e
    work.mkdir(parents=True, exist_ok=True)
    output = str(work / "audio.%(ext)s")
    run([sys.executable, "-m", "yt_dlp", "--no-playlist", "-f", "bestaudio/best", "-x", "--audio-format", "wav", "-o", output, url])
    audio = work / "audio.wav"
    if not audio.exists():
        raise RuntimeError("No se generó audio.wav")
    compute_type = "float16" if device == "cuda" else "int8"
    model = WhisperModel(model_name, device=device, compute_type=compute_type)
    stream, info = model.transcribe(str(audio), vad_filter=True)
    entries = [{"start": float(s.start), "duration": float(s.end - s.start), "text": s.text.strip()} for s in stream]
    return entries, info.language, "faster-whisper-asr"


def capture_frames(url: str, work: Path, every: int, max_frames: int) -> int:
    if not shutil.which("ffmpeg"):
        raise RuntimeError("Falta FFmpeg en PATH para extraer fotogramas")
    work.mkdir(parents=True, exist_ok=True)
    output = str(work / "video.%(ext)s")
    run([sys.executable, "-m", "yt_dlp", "--no-playlist", "-f", "bv*[height<=720]+ba/b[height<=720]/best", "--merge-output-format", "mp4", "-o", output, url])
    videos = [p for p in work.glob("video.*") if p.suffix.lower() in {".mp4", ".mkv", ".webm"}]
    if not videos:
        raise RuntimeError("No se descargó video compatible para extraer fotogramas")
    frames = work.parent / "frames"
    frames.mkdir(parents=True, exist_ok=True)
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(videos[0]), "-vf", f"fps=1/{every},scale=960:-2", "-frames:v", str(max_frames), str(frames / "frame_%04d.jpg")])
    files = sorted(frames.glob("frame_*.jpg"))
    index = [{"file": f.name, "approx_time_seconds": i * every, "approx_time": clock(i * every)} for i, f in enumerate(files)]
    (frames / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
    return len(files)


def save_transcript(dst: Path, video_id: str, url: str, segments: list[dict], language: str, method: str, frames_count: int, group_seconds: int = 60) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    (dst / "transcript.json").write_text(json.dumps(segments, ensure_ascii=False, indent=2), encoding="utf-8")
    chunks: dict[int, list[str]] = {}
    for seg in segments:
        bucket = int(seg["start"] // group_seconds)
        clean = re.sub(r"\s+", " ", seg["text"]).strip()
        chunks.setdefault(bucket, []).append(clean)
    lines = ["# Transcripción completa", "", f"- Origen: {url}", f"- Idioma detectado: {language}", f"- Método: {method}", "- Nota: los timestamps de secciones son aproximados; `transcript.json` conserva los tiempos de cada segmento.", ""]
    for bucket, content in sorted(chunks.items()):
        sec = bucket * group_seconds
        link = f"https://www.youtube.com/watch?v={video_id}&t={sec}s"
        lines += [f"## [{clock(sec)}]({link})", "", " ".join(content), ""]
    (dst / "transcript.md").write_text("\n".join(lines), encoding="utf-8")
    manifest = {"video_id": video_id, "url": url, "created_utc": datetime.now(timezone.utc).isoformat(), "language": language, "method": method, "segment_count": len(segments), "approx_last_segment_seconds": max((s["start"] + s["duration"] for s in segments), default=0), "visual_frames": frames_count}
    (dst / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    notes = dst / "notes.md"
    if not notes.exists():
        notes.write_text(f"# Video: {video_id}\n\n- Fuente: {url}\n- Estado: pendiente de análisis por Codex\n\n## Resumen\n\n## Pasos reproducibles\n\n## Luau / Explorer / plugins\n\n## Evidencia con timestamps\n\n## Visuales y dudas\n\n## Validación en Roblox Studio\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Transcribir YouTube y crear base de conocimiento para Codex Roblox")
    ap.add_argument("url", help="URL o ID de YouTube")
    ap.add_argument("--out", default="knowledge/youtube", help="Carpeta de salida desde el directorio actual")
    ap.add_argument("--langs", default="es,es-419,en", help="Prioridad de idiomas de subtítulos, separados por coma")
    ap.add_argument("--model", default="small", help="Modelo de faster-whisper si no hay subtítulos")
    ap.add_argument("--device", choices=["cpu", "cuda"], default="cpu", help="Dispositivo ASR; cuda requiere instalación GPU adecuada")
    ap.add_argument("--no-audio-fallback", action="store_true", help="No descargar audio si fallan los subtítulos")
    ap.add_argument("--frames", action="store_true", help="Descargar video y muestrear fotogramas para revisión visual")
    ap.add_argument("--frames-every", type=int, default=60, help="Espaciar fotogramas por N segundos")
    ap.add_argument("--max-frames", type=int, default=60, help="Máximo de fotogramas")
    args = ap.parse_args()
    if args.frames_every < 1 or args.max_frames < 1:
        ap.error("--frames-every y --max-frames deben ser positivos")
    video_id = video_id_from_url(args.url)
    canonical_url = f"https://www.youtube.com/watch?v={video_id}"
    dst = Path(args.out).resolve() / video_id
    dst.mkdir(parents=True, exist_ok=True)
    langs = [x.strip() for x in args.langs.split(",") if x.strip()]
    if not langs:
        ap.error("--langs no debe estar vacío")
    try:
        segments, language, method = get_captions(video_id, langs)
        print(f"Subtítulos obtenidos: {len(segments)} segmentos, {language}")
    except Exception as exc:
        print(f"No se pudieron obtener subtítulos: {type(exc).__name__}: {exc}", file=sys.stderr)
        if args.no_audio_fallback:
            return 1
        print("Intentando transcripción de audio con faster-whisper ...")
        try:
            segments, language, method = get_asr(canonical_url, dst / "media", args.model, args.device)
        except Exception as second:
            print(f"Fallback de audio falló: {type(second).__name__}: {second}", file=sys.stderr)
            print("Sugerencia: revisá subtítulos, yt-dlp, FFmpeg, faster-whisper o usá un archivo de audio autorizado.", file=sys.stderr)
            return 2
    if not segments:
        print("Error: transcripción vacía", file=sys.stderr)
        return 3
    frames_count = 0
    if args.frames:
        try:
            frames_count = capture_frames(canonical_url, dst / "media", args.frames_every, args.max_frames)
        except Exception as exc:
            print(f"Aviso: no se pudieron extraer fotogramas: {exc}", file=sys.stderr)
    save_transcript(dst, video_id, canonical_url, segments, language, method, frames_count)
    print(f"OK: {dst / 'transcript.md'}")
    print(f"OK: {dst / 'manifest.json'}")
    print(f"Fotogramas: {frames_count} (si hay); siguiente paso: pedir a Codex que use $youtube-to-knowledge")
    return 0


if __name__ == "__main__":
    sys.exit(main())
