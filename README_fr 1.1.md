# PegaseUIData

![Swift](https://img.shields.io/badge/Swift-5.7-orange) ![macOS](https://img.shields.io/badge/macOS-14-blue) ![License](https://img.shields.io/badge/License-MIT-green)

le programme est complet
il ne reste plus qu'à corriger les bugs

PegaseUIData est une application macOS développée en **SwiftUI**, permettant de **gérer et visualiser des transactions financières** de manière intuitive et efficace.

## 📸 Aperçu

![Interface](assets/screenshot.png)

## 🚀 Fonctionnalités

- 📅 **Organisation des transactions par année et par mois** avec des groupes dynamiques.
- 🔍 **Affichage et gestion des transactions** sous forme de liste interactive.
- 🎨 **Interface moderne et intuitive** en SwiftUI.
- 📂 **Sauvegarde et restauration des états d'affichage** (DisclosureGroup).
- 🛠️ **Possibilité de filtrer, supprimer ou afficher les détails des transactions.**

## 📦 Installation

### 🔧 Prérequis
- macOS 14+ (Sonoma)
- Xcode 15+
- Swift 5.7+

### 📥 Cloner le projet

```bash
git clone https://github.com/ton-utilisateur/PegaseUIData.git
cd PegaseUIData
open PegaseUIData.xcodeproj
```

### ▶️ Lancer l'application
- Ouvrir le projet avec **Xcode**.
- Sélectionner un simulateur ou une machine locale.
- **Run** (⌘ + R) pour exécuter l’application.

## 📜 Utilisation

1. **Lancer PegaseUIData** et charger les transactions existantes.
2. **Explorer les transactions** organisées par année et mois.
3. **Utiliser le menu contextuel** (clic droit) pour afficher les détails ou supprimer une transaction.
4. **Personnaliser l'affichage** grâce aux options disponibles.

## 🛠️ Contribution

Les contributions sont les bienvenues !

1. **Fork** le projet 🍴.
2. **Crée une branche** (`git checkout -b feature-nouvelle-fonction`).
3. **Commit tes modifications** (`git commit -m 'Ajout d'une nouvelle fonction'`).
4. **Push la branche** (`git push origin feature-nouvelle-fonction`).
5. **Ouvre une Pull Request** ✅.

## 📃 Licence

Ce projet est sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus d’informations.

## 🌟 Remerciements

Merci d’utiliser **PegaseUIData** ! Si ce projet t’a aidé, **n’oublie pas de laisser une ⭐ sur GitHub** 🚀.



FAQ – Foire Aux Questions

PegaseUIData est-il vraiment gratuit ?

Oui. PegaseUIData est totalement gratuit et libre d’utilisation. Il est publié sous licence MIT, ce qui signifie que vous pouvez l’utiliser, le modifier, et même redistribuer votre propre version.

Mes données sont-elles stockées en ligne ?

Non. Toutes les données sont stockées localement sur votre Mac. Il n’y a aucun envoi de vos informations sur un serveur distant.

Puis-je importer mes données bancaires ?

Oui. PegaseUIData prend en charge l’import de fichiers CSV (et d'autres formats à venir). Assurez-vous que votre fichier respecte la structure attendue (date, montant, description, etc.).

Est-il possible de gérer plusieurs comptes ?

Oui. Vous pouvez créer et suivre autant de comptes que vous le souhaitez (courant, épargne, professionnel, etc.).

Peut-on catégoriser automatiquement les opérations ?

Une catégorisation semi-automatique est proposée. PegaseUIData apprend à reconnaître les intitulés fréquents pour suggérer des catégories. Vous pouvez aussi les modifier manuellement.

Puis-je contribuer à la traduction ?

Oui ! Toute aide pour les traductions est la bienvenue. Les fichiers de localisation sont disponibles dans le dossier Resources/*.lproj.

Y a-t-il une version Windows / Linux ?

Non. PegaseUIData est développé avec SwiftUI pour macOS uniquement. Une version multiplateforme n’est pas prévue à court terme.

Comment signaler un bug ?

Vous pouvez créer un ticket sur la page Issues du dépôt GitHub :

https://github.com/thierryH91200/PegaseUIData/issues

Merci d’inclure un maximum de détails (version de macOS, étapes pour reproduire, capture d'écran si possible).



Carnets de chéques  : ok
Modes de paiement
Relevés bancaire    : ok
Echéanchier         : ok


https://blog.gingerbeardman.com/2025/06/28/automatic-build-number-incrementing-in-xcode/
