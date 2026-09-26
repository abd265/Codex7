#!/usr/bin/env python3
"""Cross-check offline C# A* against unpruned Python BFS on small boards.

Run with `python -m unittest discover -s scripts -p test_challenge_solver.py -v`.
This development check compiles the current C# source on Windows. It explicitly
skips on machines without the .NET Framework compiler (including macOS CI),
where the native Swift campaign replay tests remain the release checks.
"""
from collections import deque
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile
import unittest

import audit_campaign as geometry

ROOT = Path(__file__).resolve().parents[1]
COLORS = ('coral', 'amber', 'mint', 'sky', 'violet', 'rose')
DIRECTIONS = ('up', 'right', 'down', 'left')


def bounded_fixtures():
    # A 4x4 chamber uses the real 6x8 board's top and left boundaries. Fixed
    # walls seal the other cells, keeping exhaustive state spaces small.
    walls = tuple((x, y) for y in range(8) for x in range(6) if x >= 4 or y >= 4)
    boards = [
        ([geometry.Piece(1, 0, ((0, 0), (0, 1)), 0, 0),
          geometry.Piece(2, 1, ((0, 0), (1, 0)), 2, 1)],
         [geometry.Gate(0, 0, 0), geometry.Gate(1, 3, 1)], walls),
        # The coral L's empty corner contains amber. Its complete swept exit
        # must remain blocked until amber moves; checking only the leading
        # edge would incorrectly allow the coral exit immediately.
        ([geometry.Piece(1, 0, ((0, 0), (1, 0), (1, 1)), 0, 1),
          geometry.Piece(2, 1, ((0, 0), (0, 1)), 0, 2)],
         [geometry.Gate(0, 3, 1), geometry.Gate(1, 3, 2)], walls),
    ]
    shapes = (
        ((0, 0), (0, 1)),
        ((0, 0), (1, 0)),
        ((0, 0), (1, 0), (1, 1)),
        ((0, 0), (0, 1), (1, 1)),
        ((0, 0), (1, 0), (0, 1), (1, 1)),
    )
    for seed in range(905260, 905268):
        rng = random.Random(seed)
        pieces = []
        occupied = set()
        for identity in range(1, 4):
            for attempt in range(100):
                cells = rng.choice(shapes)
                width = max(x for x, y in cells) + 1
                height = max(y for x, y in cells) + 1
                x, y = rng.randrange(5 - width), rng.randrange(5 - height)
                piece = geometry.Piece(identity, identity - 1, cells, x, y)
                if not occupied.intersection(piece.world()):
                    pieces.append(piece)
                    occupied.update(piece.world())
                    break
            else:
                raise AssertionError('Failed to construct bounded fixture')
        gates = [geometry.Gate(0, 0, 0), geometry.Gate(1, 0, 2),
                 geometry.Gate(2, 3, seed % 3)]
        boards.append((pieces, gates, walls))
    return boards


def exhaustive_minima(board):
    """Regular breadth-first search: no heuristic or forced-exit pruning."""
    pieces, gates, walls = board
    initial = tuple(pieces)
    queue = deque([(initial, 0)])
    seen = {initial}
    first_exit = None
    while queue:
        state, distance = queue.popleft()
        if len(state) < len(initial) and first_exit is None:
            first_exit = distance
        if not state:
            return first_exit, distance, len(seen)
        for piece in state:
            for direction in range(4):
                previous = state
                for steps in range(1, 9):
                    moved, result = geometry.move(
                        state, gates, walls, (piece.id, direction, steps))
                    next_state = tuple(moved)
                    if result == 'blocked' or next_state == previous:
                        break
                    previous = next_state
                    if next_state not in seen:
                        seen.add(next_state)
                        queue.append((next_state, distance + 1))
                        if len(seen) > 100_000:
                            raise AssertionError('Fixture exceeded exhaustive-test budget')
                    if result == 'exited':
                        break
    return first_exit, None, len(seen)


def serializable_board(index, board):
    pieces, gates, walls = board
    return {
        'seed': index, 'columns': 6, 'rows': 8,
        'pieces': [{'id': p.id, 'color': COLORS[p.color],
                    'cells': [{'x': x, 'y': y} for x, y in p.cells],
                    'origin': {'x': p.x, 'y': p.y}} for p in pieces],
        'gates': [{'color': COLORS[g.color], 'side': DIRECTIONS[g.side],
                   'start': g.start, 'span': g.span} for g in gates],
        'blocked': [{'x': x, 'y': y} for x, y in walls], 'solution': [],
    }


class ExactSolverCrossChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        windows = Path(os.environ.get('WINDIR', r'C:\Windows'))
        compilers = [windows / 'Microsoft.NET' / architecture / 'v4.0.30319' / 'csc.exe'
                     for architecture in ('Framework64', 'Framework')]
        compiler = next((p for p in compilers if p.is_file()), None)
        if os.name != 'nt' or compiler is None:
            raise unittest.SkipTest('Offline C# cross-check needs Windows .NET Framework csc')
        cls.fixtures = bounded_fixtures()
        cls.expected = [exhaustive_minima(board) for board in cls.fixtures]
        with tempfile.TemporaryDirectory(prefix='prism-solver-check-') as temporary:
            directory = Path(temporary)
            executable = directory / 'ChallengeSolver.exe'
            subprocess.run([str(compiler), '/nologo', '/optimize+',
                            '/r:System.Web.Extensions.dll', '/out:' + str(executable),
                            str(ROOT / 'scripts' / 'ChallengeSolver' / 'Program.cs')],
                           check=True, capture_output=True, text=True, timeout=20)
            input_path, report_path = directory / 'input.json', directory / 'report.json'
            input_path.write_text(json.dumps([serializable_board(i, b)
                                             for i, b in enumerate(cls.fixtures)]))
            subprocess.run([str(executable), str(input_path), str(report_path), '100000'],
                           check=True, capture_output=True, text=True, timeout=20)
            cls.actual = json.loads(report_path.read_text())
        if len(cls.actual) != len(cls.fixtures):
            raise AssertionError('Solver omitted a fixture')

    def test_minimum_complete_gestures_match_unpruned_bfs(self):
        for index, (expected, actual) in enumerate(zip(self.expected, self.actual)):
            with self.subTest(fixture=index):
                minimum = expected[1]
                result = actual['complete']
                self.assertEqual(result['solved'], minimum is not None)
                if minimum is not None:
                    self.assertTrue(result['optimal'])
                    self.assertEqual(result['moves'], minimum)

    def test_minimum_first_exit_gestures_match_unpruned_bfs(self):
        for index, (expected, actual) in enumerate(zip(self.expected, self.actual)):
            with self.subTest(fixture=index):
                minimum = expected[0]
                result = actual['firstExit']
                self.assertEqual(result['solved'], minimum is not None)
                if minimum is not None:
                    self.assertTrue(result['optimal'])
                    self.assertEqual(result['moves'], minimum)

    def test_reported_solutions_replay_in_independent_geometry(self):
        for index, (board, actual) in enumerate(zip(self.fixtures, self.actual)):
            for kind in ('firstExit', 'complete'):
                with self.subTest(fixture=index, search=kind):
                    state, gates, walls = board
                    for action in actual[kind]['solution']:
                        state, result = geometry.move(state, gates, walls, (
                            action['pieceID'], DIRECTIONS.index(action['direction']), action['steps']))
                        self.assertNotEqual(result, 'blocked')
                    if actual[kind]['solved']:
                        self.assertLess(len(state), len(board[0]))
                        if kind == 'complete':
                            self.assertFalse(state)

    def test_forced_exit_and_concave_sweep_cases_are_exercised(self):
        self.assertEqual(self.expected[0][:2], (1, 2))
        pieces, gates, walls = self.fixtures[1]
        self.assertEqual(geometry.move(pieces, gates, walls, (1, 3, 1))[1], 'blocked')
        self.assertEqual(self.expected[1][:2], (1, 2))
        self.assertTrue(any(first and first > 1 for first, full, states in self.expected))
        self.assertGreater(sum(states for first, full, states in self.expected), 100)


if __name__ == '__main__':
    unittest.main(verbosity=2)

