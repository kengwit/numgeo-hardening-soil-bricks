import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

plt.rcParams['xtick.direction'] = 'in'
plt.rcParams['ytick.direction'] = 'in'

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
def cm2inch(*tupl):
    inch = 2.54
    if isinstance(tupl[0], tuple):
        return tuple(i/inch for i in tupl[0])
    else:
        return tuple(i/inch for i in tupl)

def load_data(filepath):
    """Liest eine .out-Datei ein und gibt berechnete Größen zurück."""
    data = pd.read_csv(filepath, skipinitialspace=False, delim_whitespace=True)
    eps11 = -data['stran(1)'] * 100.
    eps22 = -data['stran(2)'] * 100.
    eps33 = -data['stran(3)'] * 100.
    s11 = -data['stress(1)']
    s22 = -data['stress(2)']
    s33 = -data['stress(3)']
    epsv = eps11 + eps22 + eps33
    q = s11 - s22
    return eps11, eps22, epsv, q


# -----------------------------------------------------------------------------
# Plot
# -----------------------------------------------------------------------------
height = 6    # cm
width  = 8.5  # cm

fig, (sp1, sp2) = plt.subplots(
    nrows=1, ncols=2,
    figsize=cm2inch(2 * width, height),
    dpi=200, facecolor='white'
)

#files = ['./output_CD.out','./reference-numgeo.dat']
files = ['./output_CD.out']
labels = ['numgeo-IncDriver','numgeo']
linestyles = ['-', '--']

for filepath, label, linestyle in zip(files,labels,linestyles):
    try:
        eps11, eps22, epsv, q = load_data(filepath)
    except FileNotFoundError:
        print(f"Datei nicht gefunden, wird übersprungen: {filepath}")
        continue
    except Exception as e:
        print(f"Fehler beim Laden von {filepath}: {e}")
        continue

    if label == 'numgeo-IncDriver':
        sp1.plot(eps11, q, ls=linestyle, lw=0.75, zorder=1, label=label)
        sp2.plot(eps11, epsv, ls=linestyle, lw=0.75, zorder=1)
    else:
        sp1.plot(eps22, -q, ls=linestyle, lw=0.75, zorder=1, label=label)
        sp2.plot(eps22, epsv, ls=linestyle, lw=0.75, zorder=1)
# Achsenbeschriftungen
sp1.set_xlabel('$\\varepsilon_{1}$ in %')
sp1.set_ylabel('$q$ in kPa')
sp1.legend(loc='best')

sp2.set_xlabel('$\\varepsilon_{1}$ in %')
sp2.set_ylabel('$\\varepsilon_v$ in %')

plt.tight_layout(w_pad=1.2)
plt.show()
fig.savefig('triax_CD.pdf', bbox_inches='tight')
fig.savefig('triax_CD.png', bbox_inches='tight')