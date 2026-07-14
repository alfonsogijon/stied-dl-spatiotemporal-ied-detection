# STIED: SpatioTemporal Interictal Epileptiform Discharges detection with MEG

Official Python implementation of **STIED**, a spatiotemporal deep learning model for the automatic detection of focal interictal epileptiform discharges (IEDs) with magnetoencephalography (MEG).

[![Paper](https://img.shields.io/badge/Paper-Scientific%20Reports-blue)](https://doi.org/10.1038/s41598-025-03880-1)
[![License: CC BY-NC-ND 4.0](https://img.shields.io/badge/License-CC%20BY--NC--ND%204.0-lightgrey.svg)](http://creativecommons.org/licenses/by-nc-nd/4.0/)

---

## 📌 About the Method

**STIED** is a supervised deep learning algorithm designed to automate the identification of IEDs in focal epilepsy using MEG. To mimic the clinical expertise of neurophysiologists, the model integrates both temporal and spatial characteristics of MEG signals. It processes raw MEG epochs through two concurrent branches: a **1D-CNN** that captures the temporal morphology of the spike, and a **2D-CNN** that analyzes the 2D topographic field map to recognize the typical dipolar patterns of focal sources. Both branches are then fused into a final dense network to perform the binary classification, achieving high sensitivity and specificity.

---

## ✍️ Citation / How to Cite

If you find this repository or our model useful for your research, please cite our paper published in **Scientific Reports**:

### Format:
> Raquel Fernández-Martín, Alfonso Gijón, Odile Feys, Elodie Juvené, Alec Aeby, Charline Urbain, Xavier De Tiège, & Vincent Wens. (2025). STIED: a deep learning model for the spatiotemporal detection of focal interictal epileptiform discharges with MEG. *Scientific Reports*, 15, 21017. https://doi.org/10.1038/s41598-025-03880-1

### BibTeX (For LaTeX/Zotero users):
```bibtex
@article{fernandez2025stied,
  title={STIED: a deep learning model for the spatiotemporal detection of focal interictal epileptiform discharges with MEG},
  author={Fern{\'a}ndez-Mart{\'\i}n, Raquel and Gij{\'o}n, Alfonso and Feys, Odile and Juven{\'e}, Elodie and Aeby, Alec and Urbain, Charline and De Ti{\`e}ge, Xavier and Wens, Vincent},
  journal={Scientific Reports},
  volume={15},
  pages={21017},
  year={2025},
  publisher={Nature Publishing Group},
  doi={10.1038/s41598-025-03880-1}
}
