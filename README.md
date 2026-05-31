# 🕵️‍♂️ SHADOWHUNT – Autonomous SOC & Bug Bounty Framework

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Bash](https://img.shields.io/badge/bash-5.0+-4EAA25)
![OS](https://img.shields.io/badge/OS-Linux-orange)
![Tools](https://img.shields.io/badge/tools-50+-red)

**ShadowHunt** est un framework open source tout-en-un qui automatise les audits de sécurité, la reconnaissance OSINT, la détection de vulnérabilités, et l'intégration avec des solutions SOC/SIEM/SOAR. Conçu pour les chasseurs de bug bounty, les pentesters et les équipes SOC.

---

## ⚠️ AVERTISSEMENT LÉGAL

> **Ce script ne doit être utilisé que sur des infrastructures pour lesquelles vous disposez d’une autorisation écrite explicite.**  
> L’utilisation non autorisée est illégale et contraire à l’éthique. L’auteur décline toute responsabilité en cas d’utilisation abusive.

---

## ✨ Fonctionnalités

| Catégorie | Détails |
|-----------|---------|
| 🔍 **OSINT avancé** | Sous-domaines (Subfinder, Chaos), DNS (dnsx), WHOIS/ASN, emails (theHarvester), réseaux sociaux (Sherlock), Google Dorks, SpiderFoot, Shodan, Wayback Machine |
| 🌐 **Reconnaissance réseau** | Scan de ports (Naabu), probing HTTP (httpx), détection de technologies (whatweb), CDN (cdncheck), cloud (cloudlist), crawling (Katana) |
| 🛡️ **Scan de vulnérabilités** | Nuclei (1000+ templates), CVE mapping (cvemap), XSS (Dalfox), API endpoints (Kiterunner), fuzzing de répertoires (FFUF) |
| 🏢 **SOC/SIEM intégration** | Wazuh (alertes), osquery (endpoint), Suricata (IDS), Zeek (NSM), Velociraptor (EDR) |
| ⚡ **SOAR automation** | Workflows Shuffle, cas TheHive, partage d’IOCs MISP, Cortex analyzers, notifications JSON |
| 🧠 **IA & priorisation** | Estimation des bounties (jusqu’à $10k), analyse heuristique, support Ollama (LLM local) |
| 📊 **Rapport complet** | Markdown professionnel, tableau des vulnérabilités, mapping MITRE ATT&CK, recommandations |

---

## 📋 Prérequis

- **Système** : Linux (Ubuntu 20.04+, Debian 11+, ou dérivé)
- **Accès `sudo`** pour l’installation automatique des dépendances
- **Connexion Internet**
- **Go** et **Docker** (installés automatiquement si absents)

---

## 🚀 Installation rapide

```bash
git clone https://github.com/VOTRE_PSEUDO/shadowhunt.git
cd shadowhunt
chmod +x shadowhunt.sh
