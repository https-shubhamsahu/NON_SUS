#!/usr/bin/env python3
"""Build the 30s Burn-ad audio bed: TTS VO + dry SFX, mixed to 48 kHz stereo WAV."""
from __future__ import annotations

import asyncio
import os
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "out"
TMP = ROOT / "tmp" / "audio"
SR = 48000
DURATION = 30.0
RNG = np.random.default_rng(77)

VO_LINES = [
    # start_s, max_dur, rate, pitch, text
    (3.05, 2.85, "-10%", "-3Hz", "Some things you only want to say once."),
    (6.20, 3.50, "-8%", "-2Hz", "Burn encrypts it in your browser."),
    (10.20, 4.50, "-8%", "-2Hz", "You get a link and a two-digit code. Tell them the code."),
    (15.35, 5.40, "-6%", "-2Hz", "They open it. They read it."),
    (21.20, 2.55, "-10%", "-4Hz", "That's the only time it opens."),
    (24.15, 2.55, "-8%", "-3Hz", "Notes or one file. No account."),
    (27.15, 2.70, "-14%", "-8Hz", "NO SUS Burn. Try it at nosus.foo."),
]

VOICE = "en-US-JennyNeural"


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def to_stereo(x: np.ndarray) -> np.ndarray:
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    return x.astype(np.float32)


def length(seconds: float) -> int:
    return int(round(seconds * SR))


def fade(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n, dtype=np.float32)
    a = min(n, max(1, int(attack * SR)))
    r = min(n, max(1, int(release * SR)))
    e[:a] *= np.linspace(0, 1, a, dtype=np.float32)
    e[-r:] *= np.linspace(1, 0, r, dtype=np.float32)
    return e


def write_wav(path: Path, samples: np.ndarray) -> None:
    import wave

    stereo = to_stereo(samples)
    pcm = np.clip(stereo, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def place(bed: np.ndarray, clip: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = int(round(at * SR))
    if start >= bed.shape[0]:
        return
    x = clip * gain
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    end = min(bed.shape[0], start + x.shape[0])
    n = end - start
    bed[start:end] += x[:n]


def key_click(kind: str = "char") -> np.ndarray:
    n = length(0.038 if kind != "space" else 0.028)
    noise = RNG.standard_normal(n).astype(np.float32)
    # High mechanical tick + a little body.
    t = np.arange(n, dtype=np.float32) / SR
    body = np.sin(2 * np.pi * (kind == "space" and 420 or 2100) * t).astype(np.float32)
    high = np.sin(2 * np.pi * (kind == "period" and 3400 or 4100) * t).astype(np.float32)
    click = noise * 0.55 + body * 0.22 + high * 0.18
    click *= fade(n, 0.0006, 0.028)
    peak = float(np.max(np.abs(click)) or 1)
    return click / peak * (0.55 if kind == "space" else 0.85)


def thud() -> np.ndarray:
    n = length(0.18)
    t = np.arange(n, dtype=np.float32) / SR
    sig = (
        0.9 * np.sin(2 * np.pi * 58 * t)
        + 0.35 * np.sin(2 * np.pi * 92 * t)
        + 0.08 * RNG.standard_normal(n)
    ).astype(np.float32)
    sig *= np.exp(-t * 22)
    sig *= fade(n, 0.001, 0.05)
    return sig / (np.max(np.abs(sig)) or 1) * 0.7


def click_button() -> np.ndarray:
    n = length(0.07)
    t = np.arange(n, dtype=np.float32) / SR
    sig = (
        0.4 * RNG.standard_normal(n)
        + 0.5 * np.sin(2 * np.pi * 1600 * t)
        + 0.25 * np.sin(2 * np.pi * 900 * t)
    ).astype(np.float32)
    sig *= fade(n, 0.0004, 0.05)
    return sig / (np.max(np.abs(sig)) or 1) * 0.8


def latch() -> np.ndarray:
    n = length(0.12)
    t = np.arange(n, dtype=np.float32) / SR
    sig = (
        0.7 * np.sin(2 * np.pi * 680 * t)
        + 0.35 * np.sin(2 * np.pi * 1360 * t)
        + 0.2 * RNG.standard_normal(n)
    ).astype(np.float32)
    sig *= np.exp(-t * 28)
    sig *= fade(n, 0.0008, 0.04)
    return sig / (np.max(np.abs(sig)) or 1) * 0.65


def tick() -> np.ndarray:
    n = length(0.04)
    t = np.arange(n, dtype=np.float32) / SR
    sig = (0.5 * np.sin(2 * np.pi * 1850 * t) + 0.25 * RNG.standard_normal(n)).astype(np.float32)
    sig *= fade(n, 0.0005, 0.03)
    return sig / (np.max(np.abs(sig)) or 1) * 0.35


def drop() -> np.ndarray:
    n = length(0.16)
    t = np.arange(n, dtype=np.float32) / SR
    sig = (
        0.8 * np.sin(2 * np.pi * 110 * t)
        + 0.3 * np.sin(2 * np.pi * 220 * t)
        + 0.12 * RNG.standard_normal(n)
    ).astype(np.float32)
    sig *= np.exp(-t * 16)
    return sig / (np.max(np.abs(sig)) or 1) * 0.55


def snap() -> np.ndarray:
    n = length(0.05)
    sig = RNG.standard_normal(n).astype(np.float32)
    sig *= fade(n, 0.0003, 0.035)
    return sig / (np.max(np.abs(sig)) or 1) * 0.4


def air() -> np.ndarray:
    n = length(1.0)
    sig = RNG.standard_normal(n).astype(np.float32)
    # Very dull whoosh — filtered by a cheap moving average.
    k = 80
    kernel = np.ones(k, dtype=np.float32) / k
    sig = np.convolve(sig, kernel, mode="same")
    sig *= fade(n, 0.15, 0.35)
    return sig / (np.max(np.abs(sig)) or 1) * 0.12


def granular(seconds: float = 0.5) -> np.ndarray:
    n = length(seconds)
    sig = RNG.standard_normal(n).astype(np.float32) * 0.15
    t = np.arange(n, dtype=np.float32) / SR
    sig += 0.04 * np.sin(2 * np.pi * 900 * t)
    sig *= fade(n, 0.04, 0.08)
    return sig


def low_note() -> np.ndarray:
    n = length(2.0)
    t = np.arange(n, dtype=np.float32) / SR
    sig = (0.7 * np.sin(2 * np.pi * 55 * t) + 0.25 * np.sin(2 * np.pi * 110 * t)).astype(np.float32)
    sig *= np.exp(-t * 1.8)
    sig *= fade(n, 0.04, 0.4)
    return sig * 0.18


def build_sfx() -> np.ndarray:
    n = length(DURATION)
    bed = np.zeros((n, 2), dtype=np.float32)
    t = np.arange(n, dtype=np.float32) / SR

    # Near-silence room tone, cut dead at 0:27.
    brown = np.cumsum(RNG.standard_normal(n).astype(np.float32))
    brown -= brown.mean()
    brown /= np.max(np.abs(brown)) or 1
    room = brown * 0.012
    room *= np.clip((27.0 - t) / 0.08, 0, 1)
    bed[:, 0] += room
    bed[:, 1] += room

    # Faint electrical hum under working beats.
    hum = (0.007 * np.sin(2 * np.pi * 60 * t) + 0.003 * np.sin(2 * np.pi * 120 * t)).astype(np.float32)
    gate = ((t >= 6.0) & (t < 10.0)) | ((t >= 24.55) & (t < 26.85))
    hum *= gate.astype(np.float32)
    bed[:, 0] += hum
    bed[:, 1] += hum * 0.96

    # Typing: linear 0.45–2.35 matching the on-screen characters, with a
    # slightly longer gap after the period before "delete this."
    note = "gate code 4471. delete this."
    times = []
    t0, t1 = 0.45, 2.35
    pause_after = note.index(".")
    for i, ch in enumerate(note):
        u = i / max(len(note) - 1, 1)
        at = t0 + u * (t1 - t0)
        if i > pause_after:
            at += 0.09
        times.append(at)
    for i, (ch, at) in enumerate(zip(note, times)):
        kind = "space" if ch == " " else ("period" if ch in ".," else "char")
        place(bed, key_click(kind), at, gain=0.55)

    place(bed, thud(), 3.00, 0.55)
    place(bed, click_button(), 5.05, 0.7)

    tick_clip = tick()
    for at in np.arange(6.05, 10.0, 0.25):
        place(bed, tick_clip, float(at), 0.45)
    for at in np.arange(25.55, 26.85, 0.25):
        place(bed, tick_clip, float(at), 0.45)

    place(bed, latch(), 10.20, 0.7)
    place(bed, tick_clip, 11.00, 0.7)
    place(bed, granular(0.5), 11.20, 0.8)
    place(bed, snap(), 13.20, 0.65)
    place(bed, air(), 15.20, 1.0)
    place(bed, click_button(), 16.50, 0.45)

    # Reverse-keystroke erase, quieter and speeding up.
    keys = [key_click("char") for _ in range(18)]
    erase_from, erase_to = 18.80, 20.30
    for i, k in enumerate(keys):
        u = i / (len(keys) - 1)
        at = erase_from + (erase_to - erase_from) * (u ** 1.35)
        place(bed, k[::-1], at, gain=0.28 + 0.22 * u)

    place(bed, click_button(), 21.90, 0.35)
    # Hard cut into File — sharp low transient, no tail.
    cut = thud()[: length(0.06)] * fade(length(0.06), 0.0004, 0.04)
    place(bed, cut, 24.00, 0.9)
    place(bed, drop(), 24.60, 0.7)
    place(bed, latch(), 26.80, 0.65)
    place(bed, low_note(), 27.05, 1.0)

    peak = float(np.max(np.abs(bed)) or 1)
    if peak > 0.6:
        bed *= 0.6 / peak
    return bed


async def synth_vo_line(text: str, rate: str, pitch: str, dest: Path) -> None:
    import edge_tts

    dest.parent.mkdir(parents=True, exist_ok=True)
    comm = edge_tts.Communicate(text, VOICE, rate=rate, pitch=pitch)
    await comm.save(str(dest))


def mp3_to_wav(mp3: Path, wav: Path, max_dur: float) -> float:
    wav.parent.mkdir(parents=True, exist_ok=True)
    run([
        "ffmpeg", "-y", "-i", str(mp3),
        "-ac", "2", "-ar", str(SR),
        "-af", f"apad=pad_dur=0.05,atrim=0:{max_dur},highpass=f=70,volume=1.35,alimiter=limit=0.95",
        str(wav),
    ])
    probe = subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=nw=1:nk=1", str(wav),
    ], text=True).strip()
    return float(probe)


def load_wav(path: Path) -> np.ndarray:
    import wave

    with wave.open(str(path), "rb") as w:
        assert w.getframerate() == SR
        nch = w.getnchannels()
        frames = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
        x = frames.astype(np.float32) / 32767.0
        if nch == 2:
            x = x.reshape(-1, 2)
        else:
            x = np.stack([x, x], axis=1)
        return x


async def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    TMP.mkdir(parents=True, exist_ok=True)

    sfx = build_sfx()
    sfx_path = OUT / "sfx_bed.wav"
    write_wav(sfx_path, sfx)

    vo_clips: list[tuple[float, np.ndarray]] = []
    try:
        for i, (start, max_dur, rate, pitch, text) in enumerate(VO_LINES):
            mp3 = TMP / f"vo_{i:02d}.mp3"
            wav = TMP / f"vo_{i:02d}.wav"
            print(f"tts {i}: {text!r}", flush=True)
            await synth_vo_line(text, rate, pitch, mp3)
            mp3_to_wav(mp3, wav, max_dur)
            vo_clips.append((start, load_wav(wav)))
    except Exception as e:
        print("TTS failed:", e, file=sys.stderr)
        print("Continuing with SFX-only bed.", file=sys.stderr)
        vo_clips = []

    mix = sfx.copy()
    for start, clip in vo_clips:
        place(mix, clip, start, gain=1.0)

    peak = float(np.max(np.abs(mix)) or 1)
    if peak > 0.98:
        mix *= 0.98 / peak

    mix_path = OUT / "burn_ad_audio.wav"
    write_wav(mix_path, mix)
    print("wrote", mix_path, "vo_lines", len(vo_clips))
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
