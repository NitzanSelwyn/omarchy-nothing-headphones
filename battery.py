#!/usr/bin/python3
"""Read Nothing Ear (2) left, right and case battery over RFCOMM."""

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
BATTERY_EVENT = 0xE001


def crc16(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc & 0xFFFF


def frame(command, sequence):
    header = struct.pack("<BHHH", SOF, CTRL, command, 0) + bytes([sequence])
    return header + struct.pack("<H", crc16(header))


def frames(sock, seconds=8):
    buffer = b""
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        start = buffer.find(bytes([SOF]))
        if start > 0:
            buffer = buffer[start:]
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
    levels = {"left": -1, "right": -1, "case": -1}
    names = {2: "left", 3: "right", 4: "case"}
    if not payload:
        return levels
    for index in range(1, min(len(payload), 1 + payload[0] * 2), 2):
        if index + 1 >= len(payload):
            break
        if payload[index] in names:
            levels[names[payload[index]]] = payload[index + 1] & 0x7F
    return levels


def read_battery(address):
    with socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM) as sock:
        sock.settimeout(5)
        sock.connect((address, 15))
        sequence = 1
        sock.sendall(frame(GET_PROTOCOL_VERSION, sequence))
        battery_sent = False
        for command, payload in frames(sock):
            if command == GET_PROTOCOL_VERSION:
                sequence += 1
                sock.sendall(frame(SET_ACTIVATED, sequence))
            elif command == SET_ACTIVATED:
                sequence += 1
                sock.sendall(frame(GET_BATTERY, sequence))
                battery_sent = True
            elif command in (GET_BATTERY, BATTERY_EVENT):
                return parse_battery(payload)
        if not battery_sent:
            raise TimeoutError("activation timed out")
        raise TimeoutError("battery response timed out")


def main():
    if sys.argv[1:] == ["--self-test"]:
        assert parse_battery(bytes([3, 2, 80, 3, 72, 4, 0x80 | 90])) == {
            "left": 80, "right": 72, "case": 90
        }
        print("battery.py: self-check passed")
        return 0
    if len(sys.argv) != 2 or not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", sys.argv[1]):
        print("usage: battery.py AA:BB:CC:DD:EE:FF", file=sys.stderr)
        return 2
    try:
        print(json.dumps(read_battery(sys.argv[1]), separators=(",", ":")))
        return 0
    except (OSError, TimeoutError) as error:
        print(f"Could not read Ear (2) battery: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
