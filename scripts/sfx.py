#!/usr/bin/env python3
"""tetoOS sounds: every effect synthesised here, mixed into one audio stream.

    stdin, one command per line:
        NAME [VOLUME [PITCH]]          a named effect (pop, tap, open, close, chime,
                                       boing, crunch, jingle, lock, error, blip)
        sing VOLUME NOTE:MS NOTE:MS …  Teto sings: "la" on each note (C5, A#4, …;
                                       "-" is a rest)

One long-lived pacat stream rather than a player per sound: a click a second
for an hour would otherwise make and drop a stream a second, which screen
sharing and mixers both choke on. The stream closes after a quiet half minute
and reopens on the next sound.
"""
import math
import os
import queue
import subprocess
import sys
import threading
import time

import numpy as np

RATE = 48000
BLOCK = 480                 # 10 ms
IDLE_CLOSE = 30.0

NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def note_hz(name):
    name = name.strip()
    octave = int(name[-1])
    semi = NOTES[name[:-1]]
    return 440.0 * 2 ** ((semi + (octave - 4) * 12 - 9) / 12)


def t(sec):
    return np.arange(int(RATE * sec)) / RATE


def env(n, attack=0.004, release=0.05):
    e = np.ones(n)
    a = max(1, int(RATE * attack))
    r = max(1, int(RATE * release))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def sweep(f0, f1, sec, shape="sine"):
    x = t(sec)
    f = np.linspace(f0, f1, len(x))
    ph = 2 * np.pi * np.cumsum(f) / RATE
    if shape == "square":
        return np.sign(np.sin(ph)) * 0.6
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


def lowpass(x, a):
    try:
        from scipy.signal import lfilter
        return lfilter([a], [1, a - 1], x)
    except ImportError:
        pass
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def bell(freq, sec, decay=6.0):
    x = t(sec)
    return (np.sin(2 * np.pi * freq * x) + 0.35 * np.sin(2 * np.pi * freq * 2.01 * x)
            + 0.12 * np.sin(2 * np.pi * freq * 3.02 * x)) * np.exp(-decay * x) * 0.6


def blip(pitch=1.0):
    # Teto's "voice": a soft square chirp, the way RPG text boxes talk
    f = 520 * pitch
    x = sweep(f * 1.08, f * 0.94, 0.045, "square")
    return lowpass(x, 0.35) * env(len(x), 0.002, 0.02) * 0.55


def voice(freq, sec, vowel=0):
    """A sung syllable: a buzzy tone through two formant-ish filters, with vibrato."""
    x = t(sec)
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * x) * np.clip(x / 0.15, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / RATE
    saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
    body = lowpass(saw, 0.18) * 0.7 + lowpass(saw, 0.5) * 0.25
    e = env(len(x), 0.03, min(0.12, sec / 3))
    # "l" onset: a quick dip in brightness at the start of each syllable
    onset = np.clip(x / 0.04, 0.3, 1)
    return body * e * onset * 0.55


def noise(sec):
    return np.random.default_rng().uniform(-1, 1, int(RATE * sec))


def make(name, pitch=1.0):
    if name == "blip":
        return blip(pitch)
    if name == "pop":
        x = sweep(900 * pitch, 320 * pitch, 0.06)
        return x * env(len(x), 0.001, 0.04) * 0.5
    if name == "tap":
        x = sweep(1800 * pitch, 1200 * pitch, 0.025, "tri")
        return x * env(len(x), 0.001, 0.02) * 0.35
    if name == "open":
        x = sweep(380, 980, 0.14) * 0.4 + lowpass(noise(0.14), 0.08) * 0.25
        return x * env(len(x), 0.01, 0.08)
    if name == "close":
        x = sweep(900, 360, 0.12) * 0.35 + lowpass(noise(0.12), 0.08) * 0.2
        return x * env(len(x), 0.005, 0.07)
    if name == "chime":
        a = bell(1318.5, 0.5)
        b = bell(1975.5, 0.55)
        out = np.zeros(int(RATE * 0.68))
        out[:len(a)] += a
        out[int(RATE * 0.11):int(RATE * 0.11) + len(b)] += b
        return out * 0.7
    if name == "boing":
        x = t(0.42)
        f = 220 + 260 * np.abs(np.sin(2 * np.pi * 2.6 * x)) * np.exp(-3 * x)
        ph = 2 * np.pi * np.cumsum(f) / RATE
        return np.sin(ph) * np.exp(-4 * x) * 0.6
    if name == "crunch":
        out = np.zeros(int(RATE * 0.28))
        rng = np.random.default_rng()
        for k in range(5):
            s = int(RATE * (0.02 + k * 0.05 + rng.uniform(0, 0.01)))
            burst = lowpass(noise(0.035), 0.55) * env(int(RATE * 0.035), 0.001, 0.03) * (0.7 - k * 0.1)
            out[s:s + len(burst)] += burst
        return out * 0.6
    if name == "jingle":
        out = np.zeros(int(RATE * 0.9))
        for i, n in enumerate(["C6", "E6", "G6", "C7"]):
            b = bell(note_hz(n), 0.5, 7)
            s = int(RATE * 0.09 * i)
            out[s:s + len(b)] += b * 0.8
        return out
    if name == "lock":
        out = np.zeros(int(RATE * 0.5))
        for i, n in enumerate(["E5", "A4"]):
            b = bell(note_hz(n), 0.35, 9)
            s = int(RATE * 0.12 * i)
            out[s:s + len(b)] += b
        return out
    if name == "unlock":
        out = np.zeros(int(RATE * 0.5))
        for i, n in enumerate(["A4", "E5"]):
            b = bell(note_hz(n), 0.35, 9)
            s = int(RATE * 0.1 * i)
            out[s:s + len(b)] += b
        return out
    if name == "error":
        x = sweep(180, 160, 0.18, "square")
        return lowpass(x, 0.2) * env(len(x), 0.002, 0.05) * 0.5
    return None


def sing(score):
    parts = []
    for i, item in enumerate(score):
        note, _, ms = item.partition(":")
        sec = max(0.05, int(ms or 250) / 1000)
        if note == "-":
            parts.append(np.zeros(int(RATE * sec)))
        else:
            parts.append(voice(note_hz(note), sec, i % 2))
    return np.concatenate(parts) if parts else np.zeros(1)


class Out:
    """pacat, opened on demand and closed when quiet."""

    def __init__(self):
        self.proc = None
        self.last = 0.0

    def ensure(self):
        if self.proc and self.proc.poll() is None:
            return True
        try:
            self.proc = subprocess.Popen(
                ["pacat", "--playback", "--raw", "--format=float32le", f"--rate={RATE}",
                 "--channels=2", "--client-name=tetoOS", "--stream-name=tetoOS sounds",
                 "--latency-msec=40"],
                stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
            return True
        except OSError:
            self.proc = None
            return False

    def write(self, block):
        if not self.ensure():
            return
        try:
            self.proc.stdin.write(np.repeat(block[:, None], 2, axis=1).astype(np.float32).tobytes())
            self.proc.stdin.flush()
            self.last = time.monotonic()
        except (BrokenPipeError, OSError):
            self.proc = None

    def close(self):
        if self.proc:
            try:
                self.proc.stdin.close()
                self.proc.wait(timeout=1)
            except Exception:
                self.proc.kill()
            self.proc = None


def reader(q):
    for line in sys.stdin:
        q.put(line.strip())
    q.put(None)


def main():
    q = queue.Queue()
    threading.Thread(target=reader, args=(q,), daemon=True).start()
    voices = []                      # [samples, position]
    out = Out()
    cache = {}

    def handle(line):
        if line is None:
            return False
        parts = line.split()
        if not parts:
            return True
        name = parts[0]
        try:
            vol = float(parts[1]) if len(parts) > 1 else 0.7
            if name == "sing":
                snd = sing(parts[2:])
            else:
                pitch = float(parts[2]) if len(parts) > 2 else 1.0
                key = None if name in ("crunch", "open", "close") else (name, round(pitch, 2))
                snd = cache.get(key) if key else None
                if snd is None:
                    snd = make(name, pitch)
                    if snd is not None and key:
                        cache[key] = snd
        except (ValueError, KeyError, IndexError):
            return True
        if snd is not None:
            voices.append([snd * vol, 0])
        return True

    while True:
        if not voices:
            try:
                if not handle(q.get(timeout=1.0)):
                    break
            except queue.Empty:
                if out.proc and time.monotonic() - out.last > IDLE_CLOSE:
                    out.close()
                continue
        while True:
            try:
                line = q.get_nowait()
            except queue.Empty:
                break
            if not handle(line):
                out.close()
                return
        if voices:
            block = np.zeros(BLOCK)
            for v in voices:
                chunk = v[0][v[1]:v[1] + BLOCK]
                block[:len(chunk)] += chunk
                v[1] += BLOCK
            voices[:] = [v for v in voices if v[1] < len(v[0])]
            np.clip(block, -1, 1, out=block)
            out.write(block)
    out.close()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
