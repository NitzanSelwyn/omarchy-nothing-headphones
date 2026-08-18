#!/usr/bin/python3
"""Read battery and control ANC on Nothing/CMF earbuds over RFCOMM."""

import json
import re
import socket
import struct
import sys
import time

SOF = 0x55
CTRL = 0x0160
GET_PROTOCOL_VERSION = 0xC001
SET_ACTIVATED = 0xF001
GET_BATTERY = 0xC007
GET_ANC = 0xC01E
SET_ANC = 0xF00F
BATTERY_EVENT = 0xE001
ANC_EVENT = 0xE003
ANC_VALUES = {"high": 1, "mid": 2, "low": 3, "adaptive": 4, "off": 5, "transparency": 7}
ANC_NAMES = {value: name for name, value in ANC_VALUES.items()}


def crc16(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc & 0xFFFF


def frame(command, sequence, payload=b""):
    header = struct.pack("<BHHH", SOF, CTRL, command, len(payload)) + bytes([sequence])
    return header + payload + struct.pack("<H", crc16(header + payload))


def frames(sock, seconds=8):
    buffer = b""
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        start = buffer.find(bytes([SOF]))
        if start > 0:
            buffer = buffer[start:]
        elif start < 0:
            buffer = b""
        if len(buffer) >= 8:
            _, control, raw_command, length = struct.unpack_from("<BHHH", buffer)
            total = 8 + length + (2 if control & 0x20 else 0)
            if len(buffer) >= total:
                payload = buffer[8 : 8 + length]
                buffer = buffer[total:]
                yield raw_command | 0x8000, payload
                continue
        sock.settimeout(max(0.1, deadline - time.monotonic()))
        try:
            chunk = sock.recv(256)
        except TimeoutError:
            break
        if not chunk:
            break
        buffer += chunk


def parse_battery(payload):
    levels = {}
    names = {2: "left", 3: "right", 4: "case"}
    if not payload:
        return levels
    for index in range(1, min(len(payload), 1 + payload[0] * 2), 2):
        if index + 1 >= len(payload):
            break
        if payload[index] in names:
            levels[names[payload[index]]] = payload[index + 1] & 0x7F
    return levels


def parse_anc(payload):
    for index in range(0, len(payload) - 2, 3):
        if payload[index] == 1:
            return ANC_NAMES.get(payload[index + 1], "")
    return ""


def request(address, action, channel, mode=""):
    result = {"left": -1, "right": -1, "case": -1, "anc": ""}
    with socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM) as sock:
        sock.settimeout(5)
        sock.connect((address, channel))
        sequence = 1
        sock.sendall(frame(GET_PROTOCOL_VERSION, sequence))
        activated = False
        for command, payload in frames(sock):
            if command == GET_PROTOCOL_VERSION:
                sequence += 1
                sock.sendall(frame(SET_ACTIVATED, sequence))
            elif command == SET_ACTIVATED:
                activated = True
                sequence += 1
                if action == "anc":
                    sock.sendall(frame(SET_ANC, sequence, bytes([1, ANC_VALUES[mode], 0])))
                    return result
                sock.sendall(frame(GET_BATTERY, sequence))
                sequence += 1
                sock.sendall(frame(GET_ANC, sequence, bytes([3])))
            elif command in (GET_BATTERY, BATTERY_EVENT):
                result.update(parse_battery(payload))
            elif command in (GET_ANC, ANC_EVENT):
                result["anc"] = parse_anc(payload)
                if result["left"] >= 0 or result["right"] >= 0 or result["case"] >= 0:
                    return result
        if action == "status" and (result["left"] >= 0 or result["right"] >= 0 or result["case"] >= 0):
            return result
        raise TimeoutError("activation timed out" if not activated else "device response timed out")


def main():
    if sys.argv[1:] == ["--self-test"]:
        assert parse_battery(bytes([3, 2, 80, 3, 72, 4, 0x80 | 90])) == {
            "left": 80, "right": 72, "case": 90
        }
        assert parse_battery(bytes([1, 2, 80])) == {"left": 80}
        assert parse_anc(bytes([1, 7, 0])) == "transparency"
        assert frame(GET_BATTERY, 1).startswith(b"\x55\x60\x01\x07\xc0")
        print("nothingctl.py: self-check passed")
        return 0

    if len(sys.argv) not in (4, 5):
        print("usage: nothingctl.py ADDRESS status CHANNEL | ADDRESS anc MODE CHANNEL", file=sys.stderr)
        return 2
    address, action = sys.argv[1:3]
    mode = sys.argv[3] if action == "anc" and len(sys.argv) == 5 else ""
    channel_text = sys.argv[-1]
    if not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", address):
        print("invalid Bluetooth address", file=sys.stderr)
        return 2
    if action not in ("status", "anc") or (action == "anc" and mode not in ANC_VALUES):
        print("invalid action or ANC mode", file=sys.stderr)
        return 2
    try:
        channel = int(channel_text)
        if not 1 <= channel <= 30:
            raise ValueError
    except ValueError:
        print("RFCOMM channel must be between 1 and 30", file=sys.stderr)
        return 2
    try:
        result = request(address, action, channel, mode)
        if action == "status":
            print(json.dumps(result, separators=(",", ":")))
        return 0
    except (OSError, TimeoutError) as error:
        print(f"Could not communicate with earbuds: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
