#!/usr/bin/env python3
"""Plot convergence of the Hardening Soil internal-constant calibration.

The calibration executable writes one CSV record per Newton iteration.  This
script plots the relative residuals of the oedometer modulus and K0 targets,
together with the scalar monitor used for the convergence decision.
"""

from __future__ import annotations

import argparse
import csv
import math
import sys
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping

import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator

fontsize = 9

# LaTeX-like typography without requiring an external LaTeX installation.
# Matplotlib ships the Computer Modern fonts used here for both normal text
# and its internal MathText renderer.
plt.rcParams.update({
    'text.usetex': False,
    'font.family': 'serif',
    'font.serif': ['cmr10', 'STIXGeneral', 'DejaVu Serif'],
    'mathtext.fontset': 'cm',
    'axes.formatter.use_mathtext': True,
    'font.size': fontsize,
    'xtick.direction': 'in',
    'ytick.direction': 'in',
    'axes.spines.right': False,
    'axes.spines.top': False,
    'axes.linewidth': 1.0,
    'pdf.fonttype': 42,
    'ps.fonttype': 42,
})

layout_pad = 0.30
save_pad_inches = 0.02

# Convert centimeters to inches for figure sizing
def cm2inch(*tupl):
    inch = 2.54
    if isinstance(tupl[0], tuple):
        return tuple(i/inch for i in tupl[0])
    else:
        return tuple(i/inch for i in tupl)


@dataclass(frozen=True)
class Record:
    iteration: int
    relative_eoed: float
    relative_k0: float
    error_measure: float
    tolerance: float | None


ALIASES: Mapping[str, tuple[str, ...]] = {
    "iteration": ("iteration", "iter", "newton_iteration"),
    "relative_eoed": (
        "relative_error_eoed",
        "relative_eoed_error",
        "relative_residual_eoed",
        "eoed_relative_error",
    ),
    "relative_k0": (
        "relative_error_k0",
        "relative_k0_error",
        "relative_residual_k0",
        "k0_relative_error",
    ),
    "error_measure": (
        "error_measure",
        "monitor",
        "convergence_measure",
        "maximum_relative_error",
    ),
    "tolerance": ("tolerance", "convergence_tolerance", "tol"),
}


def _normalise(name: str) -> str:
    return name.strip().lower().replace("-", "_").replace(" ", "_")


def _resolve_columns(fieldnames: Iterable[str]) -> dict[str, str | None]:
    normalised = {_normalise(name): name for name in fieldnames}
    resolved: dict[str, str | None] = {}
    for key, aliases in ALIASES.items():
        resolved[key] = next(
            (normalised[alias] for alias in aliases if alias in normalised),
            None,
        )

    missing = [
        key
        for key in ("iteration", "relative_eoed", "relative_k0", "error_measure")
        if resolved[key] is None
    ]
    if missing:
        available = ", ".join(fieldnames)
        raise ValueError(
            "Missing required CSV columns: "
            + ", ".join(missing)
            + f". Available columns: {available}"
        )
    return resolved


def _as_float(value: str, *, column: str, row_number: int) -> float:
    try:
        result = float(value.replace("D", "E").replace("d", "e"))
    except ValueError as exc:
        raise ValueError(
            f"Invalid numerical value in column '{column}', CSV row {row_number}: "
            f"{value!r}"
        ) from exc
    if not math.isfinite(result):
        raise ValueError(
            f"Non-finite value in column '{column}', CSV row {row_number}: {value!r}"
        )
    return result


def read_history(path: Path, duplicate_policy: str) -> list[Record]:
    """Read and validate the convergence-history CSV file.

    Repeated iteration numbers are handled explicitly.  They should not occur
    in current output, but ``first`` is a safe default for legacy files that
    also recorded finite-difference perturbation evaluations.
    """

    if not path.is_file():
        raise FileNotFoundError(f"History file does not exist: {path}")

    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(
            (line for line in stream if line.strip() and not line.lstrip().startswith("#"))
        )
        if reader.fieldnames is None:
            raise ValueError(f"CSV file has no header: {path}")
        columns = _resolve_columns(reader.fieldnames)

        records_by_iteration: "OrderedDict[int, Record]" = OrderedDict()
        duplicate_count = 0
        for row_number, row in enumerate(reader, start=2):
            iteration_value = _as_float(
                row[columns["iteration"]],  # type: ignore[index]
                column=str(columns["iteration"]),
                row_number=row_number,
            )
            iteration = int(round(iteration_value))
            if abs(iteration_value - iteration) > 1.0e-9 or iteration < 0:
                raise ValueError(
                    f"Iteration must be a non-negative integer in CSV row {row_number}."
                )

            rel_eoed = abs(
                _as_float(
                    row[columns["relative_eoed"]],  # type: ignore[index]
                    column=str(columns["relative_eoed"]),
                    row_number=row_number,
                )
            )
            rel_k0 = abs(
                _as_float(
                    row[columns["relative_k0"]],  # type: ignore[index]
                    column=str(columns["relative_k0"]),
                    row_number=row_number,
                )
            )
            error_measure = abs(
                _as_float(
                    row[columns["error_measure"]],  # type: ignore[index]
                    column=str(columns["error_measure"]),
                    row_number=row_number,
                )
            )

            tolerance: float | None = None
            tolerance_column = columns["tolerance"]
            if tolerance_column is not None and row.get(tolerance_column, "").strip():
                tolerance = abs(
                    _as_float(
                        row[tolerance_column],
                        column=tolerance_column,
                        row_number=row_number,
                    )
                )

            record = Record(
                iteration=iteration,
                relative_eoed=rel_eoed,
                relative_k0=rel_k0,
                error_measure=error_measure,
                tolerance=tolerance,
            )

            if iteration in records_by_iteration:
                duplicate_count += 1
                if duplicate_policy == "last":
                    records_by_iteration[iteration] = record
                elif duplicate_policy == "minimum":
                    if record.error_measure < records_by_iteration[iteration].error_measure:
                        records_by_iteration[iteration] = record
                # ``first`` intentionally keeps the existing record.
            else:
                records_by_iteration[iteration] = record

    records = sorted(records_by_iteration.values(), key=lambda item: item.iteration)
    if not records:
        raise ValueError(f"CSV file contains no data records: {path}")

    if duplicate_count:
        print(
            f"Warning: ignored or consolidated {duplicate_count} repeated iteration "
            f"record(s) using policy '{duplicate_policy}'.",
            file=sys.stderr,
        )
    return records


def plot_history(records: list[Record], output_prefix: Path, title: str | None) -> None:
    iterations = [record.iteration for record in records]
    positive_floor = sys.float_info.min
    rel_eoed = [max(record.relative_eoed, positive_floor) for record in records]
    rel_k0 = [max(record.relative_k0, positive_floor) for record in records]
    monitor = [max(record.error_measure, positive_floor) for record in records]

    tolerances = [record.tolerance for record in records if record.tolerance is not None]
    tolerance = tolerances[-1] if tolerances else None

    colour_map = plt.colormaps["viridis"]
    colours = [colour_map(value) for value in (0.08, 0.34, 0.58, 0.78)]

    fig, ax = plt.subplots(figsize=cm2inch(10,6), constrained_layout=True)
    ax.semilogy(
        iterations,
        rel_eoed,
        marker="o",
        markersize=4.0,
        linewidth=1.4,
        linestyle="-",
        color=colours[0],
        label=r"$|r_{E_\mathrm{oed}}|/E_\mathrm{oed}^{\mathrm{ref}}$",
    )
    ax.semilogy(
        iterations,
        rel_k0,
        marker="s",
        markersize=4.0,
        linewidth=1.4,
        linestyle="--",
        color=colours[1],
        label=r"$|r_{K_0}|/K_0^{\mathrm{nc}}$",
    )
    ax.semilogy(
        iterations,
        monitor,
        marker="D",
        markersize=3.8,
        linewidth=1.7,
        linestyle="-.",
        color=colours[2],
        label="convergence measure",
    )

    if tolerance is not None and tolerance > 0.0:
        ax.axhline(
            tolerance,
            linewidth=1.2,
            linestyle=":",
            color=colours[3],
            label=rf"tolerance $={tolerance:.1e}$",
        )

    #final = records[-1]
    #final_monitor = max(final.error_measure, positive_floor)
    #ax.annotate(
    #    rf"iteration {final.iteration}: {final.error_measure:.2e}",
    #    xy=(final.iteration, final_monitor),
    #    xytext=(8, 10),
    #    textcoords="offset points",
    #    fontsize=8.5,
    #    ha="left",
    #    va="bottom",
    #    arrowprops={"arrowstyle": "->", "linewidth": 0.8},
    #)

    ax.set_xlabel("Newton iteration")
    ax.set_ylabel("relative residual / convergence measure")
    if title:
        ax.set_title(title)
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))
    ax.tick_params(which="both", direction="in")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.grid(which="major", linewidth=0.45, alpha=0.35)
    ax.grid(which="minor", linewidth=0.3, alpha=0.18)
    ax.legend(
        loc="lower left",
        frameon=True,
        framealpha=0.9,
        facecolor="white",
        fontsize=8.5,
    )

    output_prefix.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_prefix.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(output_prefix.with_suffix(".png"), dpi=600, bbox_inches="tight")
    plt.close(fig)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plot the convergence history of the HS internal-constant calibration."
    )
    parser.add_argument(
        "history",
        nargs="?",
        type=Path,
        default=Path("hs_internal_constants_convergence.csv"),
        help="CSV history file written by the calibration program.",
    )
    parser.add_argument(
        "--output-prefix",
        type=Path,
        default=Path("hs_internal_constants_convergence"),
        help="Output path without extension; PDF and PNG files are written.",
    )
    parser.add_argument("--title", default=None, help="Optional figure title.")
    parser.add_argument(
        "--duplicate-policy",
        choices=("first", "last", "minimum"),
        default="first",
        help="How repeated iteration numbers in legacy files are consolidated.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        records = read_history(args.history, args.duplicate_policy)
        plot_history(records, args.output_prefix, args.title)
    except (OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
