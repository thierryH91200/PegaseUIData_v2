# Filtre automatique sur le compte courant

## ✅ Fonctionnalité ajoutée

Le module Transaction Predicate Editor a été mis à jour pour **automatiquement filtrer les transactions par le compte courant**.

---

## 🎯 Comportement

### Avant
Le filtre utilisateur était appliqué sur **toutes** les transactions de la base de données.

### Maintenant
Le système combine automatiquement **deux prédicats** :
1. **Prédicat compte** : `account == currentAccount` (automatique)
2. **Prédicat utilisateur** : Défini via l'éditeur NSPredicateEditor (optionnel)

**Résultat** : `account == currentAccount AND [prédicat utilisateur]`

---

## 📝 Exemple

### Compte courant
```swift
CurrentAccountManager.shared.getAccount()
// → EntityAccount(name: "Mon Compte", uuid: ...)
```

### Prédicat utilisateur
```
status == "Validé"
```

### Prédicat final appliqué
```
account == <EntityAccount: Mon Compte> AND status.name == "Validé"
```

**Résultat** : Seules les transactions **du compte courant** ET **avec statut "Validé"** seront affichées.

---

## 🔧 Modifications apportées

### 1. TransactionFilterView.swift (ligne 195-311)

**Fonction `applyPredicate` mise à jour :**

```swift
func applyPredicate(_ predicate: NSPredicate?) {
    // 1️⃣ Récupérer le compte courant
    guard let currentAccount = CurrentAccountManager.shared.getAccount() else {
        print("❌ Aucun compte courant défini")
        filteredTransactions = []
        return
    }

    // 2️⃣ Créer le prédicat pour le compte courant
    let accountPredicate = NSPredicate(format: "account == %@", argumentArray: [currentAccount])

    // 3️⃣ Combiner avec le prédicat de l'éditeur
    let finalPredicate: NSPredicate
    if let userPredicate = predicate {
        // Combine avec AND
        finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            accountPredicate,
            userPredicate
        ])
    } else {
        // Utiliser seulement le prédicat compte
        finalPredicate = accountPredicate
    }

    // 4️⃣ Convertir et appliquer
    let swiftDataPredicate = TransactionPredicateParser.swiftDataPredicate(from: finalPredicate)
    // ... fetch et affichage
}
```

**Points clés :**
- ✅ Vérifie qu'un compte courant existe
- ✅ Crée automatiquement `account == currentAccount`
- ✅ Combine avec le prédicat utilisateur via `NSCompoundPredicate`
- ✅ Gestion d'erreur si le compte n'existe pas

---

### 2. TransactionPredicateParser.swift

**Ajout du support pour EntityAccount :**

#### a) Cache pour l'EntityAccount (ligne 17)
```swift
private static var cachedAccount: EntityAccount?
```

#### b) Extraction de l'EntityAccount depuis NSPredicate (ligne 490-516)
```swift
private static func extractAccountFromPredicate(_ predicate: NSPredicate) {
    cachedAccount = nil

    // Explorer les NSCompoundPredicate
    if let compound = predicate as? NSCompoundPredicate {
        for subPredicate in compound.subpredicates as? [NSPredicate] ?? [] {
            extractAccountFromPredicate(subPredicate)
            if cachedAccount != nil { return }
        }
    }

    // Extraire depuis NSComparisonPredicate
    if let comparison = predicate as? NSComparisonPredicate {
        if let keyPath = comparison.leftExpression.keyPathString,
           keyPath == "account" {
            if comparison.rightExpression.expressionType == .constantValue,
               let account = comparison.rightExpression.constantValue as? EntityAccount {
                cachedAccount = account
            }
        }
    }
}
```

**Pourquoi ?** : NSPredicate stocke l'objet EntityAccount dans le `constantValue`. On doit l'extraire avant de parser le format string.

#### c) Nouveau type ParsedValue (ligne 264-279)
```swift
private enum ParsedValue {
    case string(String)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case account(EntityAccount)  // ← NOUVEAU
}
```

#### d) Support dans parseValue (ligne 282-309)
```swift
private static func parseValue(for key: String, from rhs: String) -> ParsedValue? {
    switch key {
    case "account":
        // Utiliser l'account mis en cache
        if let account = cachedAccount {
            return .account(account)
        }
        return nil
    // ... autres cas
    }
}
```

#### e) Nouvelle fonction predicateForAccount (ligne 476-488)
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

**Important** : On compare les **UUID** pour éviter les problèmes de référence d'objet.

#### f) Extension NSExpression (ligne 521-528)
```swift
extension NSExpression {
    var keyPathString: String? {
        if expressionType == .keyPath {
            return self.keyPath
        }
        return nil
    }
}
```

**Utilité** : Facilite l'extraction du keyPath depuis un NSExpression.

---

### 3. Validator.swift (ligne 44-53)

**Ajout de "account" dans les clés autorisées :**

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

## 🔍 Flux d'exécution complet

### 1. L'utilisateur applique un filtre

```
TransactionFilterView.applyPredicate(userPredicate)
```

### 2. Récupération du compte courant

```swift
let currentAccount = CurrentAccountManager.shared.getAccount()
// → EntityAccount(name: "Compte Pro", uuid: 123-456...)
```

### 3. Création du prédicat compte

```swift
let accountPredicate = NSPredicate(format: "account == %@", argumentArray: [currentAccount])
// Format: "account == <EntityAccount 0x...>"
```

### 4. Combinaison des prédicats

```swift
let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
    accountPredicate,
    userPredicate
])
// Format: "account == <EntityAccount 0x...> AND status == 'Validé'"
```

### 5. Conversion en SwiftData

```swift
TransactionPredicateParser.swiftDataPredicate(from: finalPredicate)
```

#### 5a. Extraction de l'EntityAccount
```swift
extractAccountFromPredicate(finalPredicate)
// → cachedAccount = EntityAccount(name: "Compte Pro", uuid: 123-456...)
```

#### 5b. Parsing du format
```
"account == <EntityAccount 0x...> AND status == 'Validé'"
```

Tokenization :
- Token 1: `account == <object>`
- Token 2: AND
- Token 3: `status == 'Validé'`

#### 5c. Conversion de chaque token

**Token 1 (account):**
```swift
parseValue(for: "account", from: "<object>")
// → .account(cachedAccount)

predicateForAccount(key: "account", op: "==", value: cachedAccount)
// → #Predicate { $0.account.uuid == 123-456... }
```

**Token 3 (status):**
```swift
parseValue(for: "status", from: "Validé")
// → .string("Validé")

predicateForString(key: "status", op: "==", value: "Validé")
// → #Predicate { $0.status?.name == "Validé" }
```

#### 5d. Combinaison avec AND
```swift
#Predicate<EntityTransaction> {
    $0.account.uuid == 123-456... &&
    $0.status?.name == "Validé"
}
```

### 6. Fetch dans SwiftData

```swift
let descriptor = FetchDescriptor<EntityTransaction>(
    predicate: swiftDataPredicate,
    sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
)
filteredTransactions = try modelContext.fetch(descriptor)
```

---

## ⚠️ Points importants

### 1. Compte courant obligatoire
Si `CurrentAccountManager.shared.getAccount()` retourne `nil`, **aucune transaction ne sera affichée**.

**Vérifier :**
```swift
guard let account = CurrentAccountManager.shared.getAccount() else {
    // Afficher un message d'erreur
    return
}
```

### 2. Comparaison par UUID
On compare `$0.account.uuid == accountUUID` et non `$0.account == account` pour éviter les problèmes de référence d'objets SwiftData.

### 3. account n'est PAS optionnel
Dans EntityTransaction, `account` est défini comme :
```swift
@Relationship var account: EntityAccount
```

Donc on utilise `$0.account.uuid` (sans `?`).

### 4. Gestion d'erreur robuste
Si le parsing échoue, on revient au prédicat compte uniquement :
```swift
catch {
    // Fallback: filtrer seulement par compte
    let accountOnlyPredicate = TransactionPredicateParser.swiftDataPredicate(from: accountPredicate)
    // ...
}
```

---

## 🧪 Tests à effectuer

### Test 1: Sans filtre utilisateur
**Action** : Ouvrir TransactionFilterView sans créer de filtre

**Résultat attendu** :
- Toutes les transactions du compte courant s'affichent
- Logs : `account == <EntityAccount: ...>`

### Test 2: Avec filtre status
**Action** : Créer un filtre `status == "Validé"`

**Résultat attendu** :
- Seules les transactions du compte courant ET avec statut "Validé"
- Logs : `account == <EntityAccount: ...> AND status == "Validé"`

### Test 3: Avec filtre combiné
**Action** : Créer `status == "Validé" AND dateOperation > [date]`

**Résultat attendu** :
- Transactions du compte courant ET validées ET après la date
- Logs : `account == <EntityAccount: ...> AND (status == "Validé" AND dateOperation > ...)`

### Test 4: Sans compte courant
**Action** : Déconnecter le compte (`CurrentAccountManager.shared.clearAccount()`)

**Résultat attendu** :
- Aucune transaction affichée
- Logs : `❌ Aucun compte courant défini`

---

## 📊 Logs de debug

Lors de l'application d'un filtre, vous verrez :

```
🔍 Application du prédicat...
   → Compte courant: Mon Compte Pro
   → Prédicat compte: account == <EntityAccount 0x123...>
   → Prédicat utilisateur: status == "Validé"
   → Prédicat combiné: account == <EntityAccount 0x123...> AND status == "Validé"
   → Validation du prédicat...
   ✅ Prédicat valide
   → Conversion en SwiftData Predicate...
      [Parser] Format original: account == <EntityAccount 0x123...> AND status == "Validé"
      [Parser] EntityAccount trouvé: Mon Compte Pro (123-456...)
      [Parser] Format normalisé: account == <EntityAccount 0x123...> AND status == "Validé"
      [Parser] Expression composée avec 3 tokens
         [Binary] lhs='account', op='==', rhs='<EntityAccount 0x123...>'
         [Binary] Type parsé: account(EntityAccount)
         [Binary] → Création prédicat Account
         [Binary] Résultat: ✅
         [Binary] lhs='status', op='==', rhs='"Validé"'
         [Binary] Type parsé: string("Validé")
         [Binary] → Création prédicat String
         [Binary] Résultat: ✅
      [Parser] Résultat: ✅ Succès
   ✅ Prédicat SwiftData créé
   → Création du FetchDescriptor...
   → Fetch en cours...
   ✅ Fetch réussi: 42 résultats
```

---

## 🎉 Avantages

1. **Isolation automatique** : Les transactions sont toujours filtrées par compte
2. **Sécurité** : Impossible de voir les transactions d'un autre compte
3. **Simplicité** : L'utilisateur n'a pas besoin de spécifier le compte dans ses filtres
4. **Compatibilité** : Fonctionne avec tous les autres filtres (status, date, montant, etc.)
5. **Performance** : SwiftData peut optimiser la requête avec l'index sur account

---

## 🔄 Migration depuis l'ancienne version

Si vous utilisiez déjà TransactionFilterView, **aucune modification nécessaire** !

Le filtre sur le compte se fait maintenant automatiquement en arrière-plan.

---

**Auteur** : Claude
**Date** : 16 janvier 2026
**Version** : 2.0 (avec support account)
