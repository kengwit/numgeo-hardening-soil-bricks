import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

FONTSIZE = 10

plt.rcParams['xtick.direction'] = 'in'
plt.rcParams['ytick.direction'] = 'in'
#plt.rcParams['text.usetex'] = True
plt.rcParams['font.size'] = FONTSIZE
plt.rcParams['axes.spines.right'] = False
plt.rcParams['axes.spines.top'] = False

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
def cm2inch(*tupl):
    inch = 2.54
    if isinstance(tupl[0], tuple):
        return tuple(i/inch for i in tupl[0])
    else:
        return tuple(i/inch for i in tupl)

def load_data_abq(filepath):
    """Liest eine .out-Datei ein und gibt berechnete Größen zurück."""
    data = np.genfromtxt(filepath, skip_header=4)
    eps11 = -data[:,1] * 100.
    eps22 = -data[:,3] * 100.
    eps33 = -data[:,4] * 100.
    s11 = -data[:,5]
    s22 = -data[:,7]
    s33 = -data[:,8]
    epsv = eps11 + eps22 + eps33
    q = s22 - s11
    return eps11, eps22, epsv, q

def load_data_numgeo(filepath):
    """Liest eine .out-Datei ein und gibt berechnete Größen zurück."""
    data = np.genfromtxt(filepath, skip_header=4)
    eps11 = -data[:,7] * 100.
    eps22 = -data[:,8] * 100.
    eps33 = -data[:,9] * 100.
    s11 = -data[:,1]
    s22 = -data[:,2]
    s33 = -data[:,3]
    epsv = eps11 + eps22 + eps33
    q = s22 - s11
    return eps11, eps22, epsv, q


# -----------------------------------------------------------------------------
# Plot
# -----------------------------------------------------------------------------
height = 6    # cm
width  = 8.5  # cm

fig, (sp1, sp2) = plt.subplots(
    nrows=1, ncols=2,
    figsize=cm2inch(2 * width, height),
    dpi=600, facecolor='white'
)

#files = ['./output_CD.out','./reference-numgeo.dat']
files = ['./abaqus-result.dat', './numgeo-result.dat']
labels = ['Abaqus with numgeo HS-Bricks', 'numgeo HS-Bricks']
linestyles = ['-','--']

for filepath, label, linestyle in zip(files,labels,linestyles):
    try:
        if filepath == './abaqus-result.dat':
            eps11, eps22, epsv, q = load_data_abq(filepath)
            sp1.plot(eps22, q, ls=linestyle, lw=0.75, zorder=1, label=label)
            sp2.plot(eps22, epsv, ls=linestyle, lw=0.75, zorder=1)
        else:
            eps11, eps22, epsv, q = load_data_numgeo(filepath)
            sp1.plot(eps22, q, ls=linestyle, lw=0.75, zorder=1, label=label, marker='x', markevery=0.1)
            sp2.plot(eps22, epsv, ls=linestyle, lw=0.75, zorder=1, marker='x', markevery=0.1)
    except FileNotFoundError:
        print(f"Datei nicht gefunden, wird übersprungen: {filepath}")
        continue
    except Exception as e:
        print(f"Fehler beim Laden von {filepath}: {e}")
        continue
    
# Achsenbeschriftungen
sp1.set_xlabel('$\\varepsilon_{1}$ in %')
sp1.set_ylabel('$q$ in kPa')
sp1.legend(loc='best', fontsize=FONTSIZE-1)

sp2.set_xlabel('$\\varepsilon_{1}$ in %')
sp2.set_ylabel('$\\varepsilon_v$ in %')

plt.tight_layout(w_pad=1.2)
plt.show()
fig.savefig('triax_CD_abq.pdf', bbox_inches='tight')
fig.savefig('triax_CD_abq.png', bbox_inches='tight')