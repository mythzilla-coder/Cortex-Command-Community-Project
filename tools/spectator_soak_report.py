"""Parse SPECTATOR_EVENT lines emitted by SpectatorArena."""
import re
import sys
from collections import Counter

EVENT = re.compile(r"^(?:PRINT:\s+)?SPECTATOR_EVENT\s+event=(\S+)(?:\s+(.*))?$")

def parse(lines):
    events, winners, durations, watchdogs = 0, Counter(), [], 0
    starts, completed = 0, 0
    for line in lines:
        match = EVENT.match(line.strip())
        if not match:
            continue
        fields = {p.split("=", 1)[0]: p.split("=", 1)[1] for p in (match.group(2) or "").split() if "=" in p}
        event = match.group(1)
        events += 1
        if event == "ROUND_START": starts += 1
        elif event == "ROUND_RESULT":
            completed += 1
            winner = fields.get("winner", "UNKNOWN")
            winners[winner] += 1
            try:
                durations.append(float(fields["durationMS"]))
            except (KeyError, TypeError, ValueError):
                pass
        elif event == "WATCHDOG": watchdogs += 1
    report = {
        "events": events, "rounds_started": starts, "rounds_completed": completed,
        "incomplete_final_round": starts > completed, "watchdog_events": watchdogs,
        "winners": dict(sorted(winners.items())),
        "duration_ms": {"average": sum(durations) / len(durations) if durations else None,
                        "shortest": min(durations) if durations else None,
                        "longest": max(durations) if durations else None},
    }
    return report

def format_report(report):
    d = report["duration_ms"]
    return "\n".join([
        f"rounds: {report['rounds_completed']}/{report['rounds_started']} completed",
        f"incomplete_final_round: {str(report['incomplete_final_round']).lower()}",
        f"winners: {report['winners']}",
        f"duration_ms: average={d['average']} shortest={d['shortest']} longest={d['longest']}",
        f"watchdog_events: {report['watchdog_events']}",
    ])

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "-"
    stream = sys.stdin if path == "-" else open(path, encoding="utf-8", errors="replace")
    try: print(format_report(parse(stream)))
    finally:
        if path != "-": stream.close()
