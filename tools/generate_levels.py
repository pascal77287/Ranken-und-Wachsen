"""Erzeugt Level-Kandidaten für Wachsen & Verflechten und bewertet sie.

Die Ranken werden rückwärts von der Ziel-Knospe aus gelegt (zufällige Wege mit
Warnsdorff-Vorliebe); übrig bleibende Felder werden zu Steinen. Ein Löser mit
denselben Regeln wie LevelSolver zählt die Lösungen (bis 2) und misst den
Suchaufwand als grobes Mass für die Schwierigkeit.

Aufruf:
    python tools/generate_levels.py BREITE HOEHE RANKEN [--stones N] [--min-stones N]
        [--tries N] [--attempts N] [--seed N] [--show N] [--min-len N] [--nodes N]

Ausgabe: die besten eindeutigen Kandidaten als JSON-Zeilen im Level-Format.
"""

import argparse
import json
import random
import sys

DIRS = {"U": (0, -1), "D": (0, 1), "L": (-1, 0), "R": (1, 0)}
NEIGH = [(0, -1), (1, 0), (0, 1), (-1, 0)]


def generate(w, h, k, max_stones, rng, min_len=4):
    cells = {(x, y) for x in range(w) for y in range(h)}
    # Einige Steine vorab setzen; sie machen Lösungen oft eindeutig.
    for _ in range(rng.randint(0, max_stones // 2)):
        cells.discard((rng.randrange(w), rng.randrange(h)))
    goal = (rng.randrange(w), rng.randrange(h))
    if goal not in cells:
        return None
    entries = [(goal[0] + dx, goal[1] + dy) for dx, dy in NEIGH]
    entries = [c for c in entries if c in cells]
    if len(entries) < k:
        return None
    rng.shuffle(entries)
    used = {goal}
    paths = []
    for e in entries[:k]:
        paths.append([e])
        used.add(e)

    def free_neighbors(c):
        return [(c[0] + dx, c[1] + dy) for dx, dy in NEIGH if (c[0] + dx, c[1] + dy) in cells and (c[0] + dx, c[1] + dy) not in used]

    active = list(range(k))
    while active:
        i = rng.choice(active)
        opts = free_neighbors(paths[i][-1])
        if not opts:
            active.remove(i)
            continue
        # Warnsdorff: Felder mit wenigen freien Nachbarn zuerst, mit etwas Zufall.
        opts.sort(key=lambda c: len(free_neighbors(c)) + rng.random() * 1.6)
        nxt = opts[0]
        paths[i].append(nxt)
        used.add(nxt)

    _fill_detours(paths, cells, used, rng)

    stones = {(x, y) for x in range(w) for y in range(h)} - used
    if len(stones) > max_stones:
        return None
    if any(len(p) < min_len for p in paths):
        return None
    grid = [["." for _ in range(w)] for _ in range(h)]
    for x, y in stones:
        grid[y][x] = "X"
    grid[goal[1]][goal[0]] = "Z"
    # Startknospen in Lesereihenfolge nummerieren.
    order = sorted(range(k), key=lambda i: (paths[i][-1][1], paths[i][-1][0]))
    solution = {}
    for n, i in enumerate(order, 1):
        p = list(reversed(paths[i])) + [goal]
        sx, sy = p[0]
        grid[sy][sx] = str(n)
        moves = ""
        for a, b in zip(p, p[1:]):
            d = (b[0] - a[0], b[1] - a[1])
            moves += next(m for m, v in DIRS.items() if v == d)
        solution[str(n)] = moves
    return {"grid": ["".join(r) for r in grid], "solution": solution}


def _fill_detours(paths, cells, used, rng):
    """Baut freie Felder als Umwege ein: Liegen zwei benachbarte freie Felder
    c, d neben aufeinanderfolgenden Rankenfeldern a, b, wird a-b zu a-c-d-b.
    Freie Felder neben dem äusseren Ende verlängern die Ranke."""

    def adjacent(a, b):
        return abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1

    changed = True
    while changed:
        changed = False
        free = [c for c in cells if c not in used]
        rng.shuffle(free)
        for path in paths:
            for c in free:
                if c in used:
                    continue
                if adjacent(path[-1], c):
                    path.append(c)
                    used.add(c)
                    changed = True
                    continue
                for j in range(len(path) - 1):
                    a, b = path[j], path[j + 1]
                    if not adjacent(a, c):
                        continue
                    d = (c[0] + b[0] - a[0], c[1] + b[1] - a[1])
                    if d in cells and d not in used and adjacent(d, b):
                        path[j + 1:j + 1] = [c, d]
                        used.update((c, d))
                        changed = True
                        break


class Solver:
    """Gleiche Regeln und gleiches Pruning wie scripts/core/level_solver.gd."""

    def __init__(self, grid, node_limit=300_000):
        self.h = len(grid)
        self.w = len(grid[0])
        self.passable = set()
        self.starts = {}
        for y, row in enumerate(grid):
            for x, ch in enumerate(row):
                if ch != "X":
                    self.passable.add((x, y))
                if ch == "Z":
                    self.goal = (x, y)
                elif ch.isdigit():
                    self.starts[int(ch)] = (x, y)
        self.starts = [self.starts[n] for n in sorted(self.starts)]
        self.k = len(self.starts)
        self.node_limit = node_limit
        self.nodes = 0
        self.aborted = False
        self.solutions = 0
        self.occ = {c: -1 for c in self.passable}
        self.paths = [[s] for s in self.starts]
        for i, s in enumerate(self.starts):
            self.occ[s] = i

    def count(self, limit=2):
        self.limit = limit
        try:
            self._extend(0)
        except _Abort:
            self.aborted = True
        return self.solutions

    def _links(self, c, active, tip):
        entries = goal = 0
        for dx, dy in NEIGH:
            m = (c[0] + dx, c[1] + dy)
            if m not in self.passable:
                continue
            if m == self.goal:
                goal = 1
                continue
            o = self.occ[m]
            if o == -1 or (m == tip and o == active) or (o > active and len(self.paths[o]) == 1):
                entries += 1
        return entries >= 1 and entries + goal >= 2

    def _goal_ok(self, active, tip):
        open_ = 0
        for dx, dy in NEIGH:
            m = (self.goal[0] + dx, self.goal[1] + dy)
            if m not in self.passable:
                continue
            o = self.occ[m]
            if o == -1 or (m == tip and o == active) or (o > active and len(self.paths[o]) == 1):
                open_ += 1
        return open_ >= self.k - active

    def _local_ok(self, n, i):
        for dx, dy in NEIGH:
            m = (n[0] + dx, n[1] + dy)
            if m != self.goal and m in self.passable and self.occ[m] == -1 and not self._links(m, i, n):
                return False
        return self._goal_ok(i, n)

    def _feasible(self, active, tip):
        for c in self.passable:
            if c != self.goal and self.occ[c] == -1 and not self._links(c, active, tip):
                return False
        return self._goal_ok(active, tip)

    def _extend(self, i):
        if self.solutions >= self.limit:
            return
        self.nodes += 1
        if self.nodes > self.node_limit:
            raise _Abort()
        path = self.paths[i]
        t = path[-1]
        if t == self.goal:
            if i + 1 == self.k:
                if all(o != -1 for c, o in self.occ.items() if c != self.goal):
                    self.solutions += 1
                return
            if self._feasible(i + 1, self.paths[i + 1][0]):
                self._extend(i + 1)
            return
        for dx, dy in NEIGH:
            n = (t[0] + dx, t[1] + dy)
            if n not in self.passable:
                continue
            if n == self.goal:
                path.append(n)
                self._extend(i)
                path.pop()
                continue
            if self.occ[n] != -1:
                continue
            self.occ[n] = i
            path.append(n)
            if self._local_ok(n, i):
                self._extend(i)
            path.pop()
            self.occ[n] = -1


class _Abort(Exception):
    pass


def difficulty(grid, node_limit):
    s = Solver(grid, node_limit)
    count = s.count()
    return count, s.nodes, s.aborted


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("w", type=int)
    ap.add_argument("h", type=int)
    ap.add_argument("k", type=int)
    ap.add_argument("--stones", type=int, default=3)
    ap.add_argument("--min-stones", type=int, default=0)
    ap.add_argument("--tries", type=int, default=400)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--show", type=int, default=5)
    ap.add_argument("--min-len", type=int, default=4)
    ap.add_argument("--nodes", type=int, default=300_000)
    ap.add_argument("--attempts", type=int, default=5000)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    seen = set()
    found = []
    for _ in range(a.attempts):
        if len(found) >= a.tries:
            break
        lv = generate(a.w, a.h, a.k, a.stones, rng, a.min_len)
        if lv is None:
            continue
        stones = sum(r.count("X") for r in lv["grid"])
        if stones < a.min_stones or tuple(lv["grid"]) in seen:
            continue
        seen.add(tuple(lv["grid"]))
        count, nodes, aborted = difficulty(lv["grid"], a.nodes)
        if count == 1 and not aborted:
            found.append((nodes, lv))
    found.sort(key=lambda f: -f[0])
    print(f"{len(found)} eindeutige Kandidaten", file=sys.stderr)
    for nodes, lv in found[: a.show]:
        print(json.dumps({"nodes": nodes, **lv}, ensure_ascii=False))


if __name__ == "__main__":
    main()
