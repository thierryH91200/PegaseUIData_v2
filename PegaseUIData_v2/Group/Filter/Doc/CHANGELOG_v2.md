# Changelog - Transaction Predicate Editor v2.0

## Version 2.0 - 16 janvier 2026

### 🆕 Nouvelle fonctionnalité majeure : Filtre automatique sur le compte courant

Le module filtre maintenant **automatiquement** toutes les transactions par le compte courant défini dans `CurrentAccountManager`.

---

## 🎯 Changements principaux

### 1. Filtre automatique par compte

**Comportement** :
- Toutes les requêtes incluent automatiquement `account == currentAccount`
- Le prédicat utilisateur est combiné avec le prédicat compte via `AND`
- Si aucun compte courant n'est défini, aucune transaction n'est retournée

**Code avant (v1.0)** :
```swift
func applyPredicate(_ predicate: NSPredicate?) {
    let swiftDataPredicate = TransactionPredicateParser.swiftDataPredicate(from: predicate)
    let descriptor = FetchDescriptor<EntityTransaction>(predicate: swiftDataPredicate)
    filteredTransactions = try modelContext.fetch(descriptor)
}
```

**Code après (v2.0)** :
```swift
func applyPredicate(_ predicate: NSPredicate?) {
    guard let currentAccount = CurrentAccountManager.shared.getAccount() else {
        filteredTransactions = []
        return
    }

    let accountPredicate = NSPredicate(format: "account == %@", argumentArray: [currentAccount])

    let finalPredicate: NSPredicate
    if let userPredicate = predicate {
        finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            accountPredicate,
            userPredicate
        ])
    } else {
        finalPredicate = accountPredicate
    }

    let swiftDataPredicate = TransactionPredicateParser.swiftDataPredicate(from: finalPredicate)
    // ... fetch
}
```

---

### 2. Support d'EntityAccount dans le parser

**Nouveau type de valeur** :
```swift
private enum ParsedValue {
    case string(String)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case account(EntityAccount)  // ← NOUVEAU
}
```

**Nouvelle fonction de parsing** :
```swift
private static func predicateForAccount(key: String, op: String, value: EntityAccount) -> Predicate<EntityTransaction>? {
    guard key == "account" else { return nil }

    let accountUUID = value.uuid

    switch op {
    case "==": return #Predicate { $0.account.uuid == accountUUID }
    case "!=": return #Predicate { $0.account.uuid != accountUUID }
    default: return nil
    }
}
```

**Extraction de l'EntityAccount depuis NSPredicate** :
```swift
private static func extractAccountFromPredicate(_ predicate: NSPredicate) {
    // Explore NSCompoundPredicate et NSComparisonPredicate
    // Extrait l'objet EntityAccount depuis constantValue
    // Stocke dans cachedAccount
}
```

---

### 3. Validation étendue

**Ajout de "account" dans les clés autorisées** :
```swift
static let allowedKeys: Set<String> = [
    "account",        // ← NOUVEAU
    "amount",
    "dateOperation",
    "datePointage",
    "status",
    "mode",
    "bankStatement",
    "checkNumber"
]
```

---

## 📋 Fichiers modifiés

### TransactionFilterView.swift
- **Ligne 195-311** : Modification complète de `applyPredicate(_:)`
- Ajout de la récupération du compte courant
- Création du prédicat compte
- Combinaison avec le prédicat utilisateur
- Gestion d'erreur si pas de compte courant

### TransactionPredicateParser.swift
- **Ligne 17** : Ajout de `cachedAccount` pour stocker l'EntityAccount
- **Ligne 31** : Appel de `extractAccountFromPredicate` au début du parsing
- **Ligne 264-279** : Ajout du case `.account(EntityAccount)` dans `ParsedValue`
- **Ligne 256-258** : Gestion du case `.account` dans `predicateForBinary`
- **Ligne 282-309** : Support de `"account"` dans `parseValue`
- **Ligne 476-488** : Nouvelle fonction `predicateForAccount`
- **Ligne 490-516** : Nouvelle fonction `extractAccountFromPredicate`
- **Ligne 521-528** : Extension `NSExpression` avec `keyPathString`

### Validator.swift
- **Ligne 45** : Ajout de `"account"` dans `allowedKeys`

---

## 📊 Exemples d'utilisation

### Exemple 1 : Sans filtre utilisateur
```swift
// L'utilisateur n'a pas créé de filtre
TransactionFilterView()
```

**Prédicat appliqué** :
```
account == <EntityAccount: Mon Compte>
```

**Résultat** : Toutes les transactions du compte courant

---

### Exemple 2 : Avec filtre status
```swift
// L'utilisateur crée le filtre: status == "Validé"
```

**Prédicat appliqué** :
```
account == <EntityAccount: Mon Compte> AND status.name == "Validé"
```

**Résultat** : Transactions du compte courant avec statut "Validé"

---

### Exemple 3 : Avec filtre combiné
```swift
// L'utilisateur crée: status == "Validé" AND dateOperation > [date]
```

**Prédicat appliqué** :
```
account == <EntityAccount: Mon Compte> AND (status.name == "Validé" AND dateOperation > [date])
```

**Résultat** : Transactions du compte courant, validées, après la date

---

## 🔧 Migration depuis v1.0

### Pas de modification nécessaire dans votre code !

Si vous utilisez déjà `TransactionFilterView`, tout continue de fonctionner.

**La seule différence** : Les transactions sont maintenant automatiquement filtrées par compte courant.

### Cas particulier : Si vous ne voulez PAS filtrer par compte

**Option 1** : Ne pas utiliser `TransactionFilterView`, utiliser directement le parser
```swift
let predicate = NSPredicate(format: "status == 'Validé'")
let swiftDataPredicate = TransactionPredicateParser.swiftDataPredicate(from: predicate)
// Fetch sans restriction de compte
```

**Option 2** : Créer une vue personnalisée sans le filtre compte
```swift
// Copier TransactionFilterView et retirer les lignes 203-227
```

---

## ⚠️ Breaking Changes

### 1. Compte courant obligatoire

**Avant v2.0** : Si pas de compte courant, toutes les transactions étaient affichées

**À partir de v2.0** : Si pas de compte courant, **aucune transaction** n'est affichée

**Solution** : Toujours définir un compte courant avant d'utiliser la vue
```swift
CurrentAccountManager.shared.setAccount(accountID)
```

### 2. Performances

**Impact positif** : Les requêtes sont plus rapides car SwiftData peut utiliser l'index sur `account`.

**Impact négatif** : Si vous vouliez voir toutes les transactions (tous comptes confondus), ce n'est plus possible avec `TransactionFilterView`.

---

## 🐛 Corrections de bugs

Aucune correction dans cette version (v1.0 était déjà stable).

---

## 🧪 Tests effectués

### Test 1 : Sans compte courant
✅ Affiche un message d'erreur et aucune transaction

### Test 2 : Avec compte courant, sans filtre
✅ Affiche toutes les transactions du compte courant

### Test 3 : Avec compte courant + filtre status
✅ Combine correctement les deux prédicats

### Test 4 : Compilation
✅ Build réussit sans erreurs ni warnings

---

## 📚 Documentation ajoutée

### ACCOUNT_FILTER.md (nouveau fichier)
- Explication détaillée du filtre automatique
- Flux d'exécution complet
- Exemples de logs
- Guide de migration

### STATUS.md (mis à jour)
- Ajout d'`account` dans la liste des champs
- Référence vers `ACCOUNT_FILTER.md`
- Mise à jour des fonctionnalités

---

## 🚀 Améliorations futures possibles

### 1. Support multi-comptes
Permettre de filtrer sur plusieurs comptes simultanément :
```swift
accounts IN [compte1, compte2, compte3]
```

### 2. Option pour désactiver le filtre compte
Ajouter un paramètre booléen :
```swift
TransactionFilterView(filterByCurrentAccount: false)
```

### 3. Sélection du compte dans l'interface
Ajouter un picker pour changer de compte sans quitter la vue.

---

## 📝 Notes pour les développeurs

### Pourquoi comparer les UUID et non les objets ?
```swift
// ❌ NE PAS FAIRE
#Predicate { $0.account == account }

// ✅ FAIRE
#Predicate { $0.account.uuid == accountUUID }
```

**Raison** : SwiftData peut avoir des problèmes de référence d'objets. Les UUID garantissent une comparaison fiable.

### Pourquoi utiliser argumentArray ?
```swift
// ❌ NE PAS FAIRE
NSPredicate(format: "account == %@", currentAccount)
// Erreur: EntityAccount ne conforme pas à CVarArg

// ✅ FAIRE
NSPredicate(format: "account == %@", argumentArray: [currentAccount])
```

**Raison** : `argumentArray` accepte n'importe quel objet, contrairement aux variadic arguments.

### Pourquoi extraire l'EntityAccount avant le parsing ?
```swift
extractAccountFromPredicate(nsPredicate)
```

**Raison** : Le format string de NSPredicate contient `<EntityAccount 0x...>` qui n'est pas parsable. L'objet réel est stocké dans `constantValue` et doit être extrait manuellement.

---

## ✅ Checklist de migration

- [ ] Vérifier que `CurrentAccountManager.shared.getAccount()` ne retourne jamais `nil` dans votre app
- [ ] Tester tous les filtres existants
- [ ] Vérifier que les performances sont bonnes
- [ ] Lire `ACCOUNT_FILTER.md` pour comprendre le fonctionnement
- [ ] Mettre à jour votre documentation si vous référencez le module

---

## 👥 Contributeurs

**Développeur** : Claude
**Date de release** : 16 janvier 2026
**Version** : 2.0

---

## 📞 Support

En cas de problème :
1. Consultez `ACCOUNT_FILTER.md`
2. Vérifiez les logs de la console
3. Assurez-vous qu'un compte courant est défini
4. Consultez `DEBUG_GUIDE.md`

---

**Fin du changelog v2.0**
