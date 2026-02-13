# Guide de debug - Transaction Predicate Editor

## 🐛 Le fetch plante - Comment débugger

J'ai ajouté des logs détaillés pour vous aider à identifier le problème. Voici comment les utiliser :

### 1. Lancer l'application avec la console

1. Ouvrez Xcode
2. Lancez l'application (Cmd+R)
3. Ouvrez la console de debug (Cmd+Shift+Y)
4. Créez un filtre dans l'application

### 2. Interpréter les logs

Les logs suivent cette structure :

```
🔍 Application du prédicat...
   → NSPredicate format: amount > 100
   → Validation du prédicat...
   ✅ Prédicat valide
   → Conversion en SwiftData Predicate...
      [Parser] Format original: amount > 100
      [Parser] Format normalisé: amount > 100
      [Parser] Format sans parenthèses: amount > 100
      [Parser] Tokens: 1
      [Parser] Expression simple: amount > 100
         [Binary] Expression: amount > 100
         [Binary] lhs='amount', op='>', rhs='100'
         [Binary] cleanedRHS='100'
         [Binary] Type parsé: double(100.0)
         [Binary] → Création prédicat Double
         [Binary] Résultat: ✅
      [Parser] Résultat: ✅ Succès
   ✅ Prédicat SwiftData créé
   → Création du FetchDescriptor...
   → Fetch en cours...
   ✅ Fetch réussi: 42 résultats
```

### 3. Identifier le problème

#### Problème A: Le parser échoue

Si vous voyez :
```
[Parser] Résultat: ❌ Échec
```

**Causes possibles:**
- Le champ utilisé n'est pas supporté
- L'opérateur n'est pas reconnu
- La valeur ne peut pas être parsée

**Solution:** Regardez les logs `[Binary]` pour voir exactement où ça échoue.

#### Problème B: Le fetch plante

Si vous voyez :
```
❌ Erreur de fetch : ...
```

**Causes possibles:**

1. **Champ inexistant sur EntityTransaction**
   ```
   ❌ Erreur de fetch : KeyPath ... does not exist
   ```
   → Le champ utilisé dans le prédicat n'existe pas sur EntityTransaction
   → Vérifiez que le champ existe bien dans `EntityTransaction.swift`

2. **Type incompatible**
   ```
   ❌ Erreur de fetch : Type mismatch
   ```
   → Le type de la valeur ne correspond pas au type du champ
   → Exemple: chercher un String dans un champ Double

3. **Propriété calculée non supportée**
   ```
   ❌ Erreur de fetch : Cannot filter on computed property 'amount'
   ```
   → SwiftData ne peut pas filtrer directement sur `amount` car c'est une propriété calculée
   → **Solution:** Voir section "Problème spécifique: amount"

### 4. Problème spécifique: La propriété `amount`

`amount` est une **propriété calculée** dans EntityTransaction :

```swift
var amount: Double {
    sousOperations.reduce(0.0) { $0 + $1.amount }
}
```

**Problème:** SwiftData **ne peut pas** filtrer sur les propriétés calculées car elles n'existent pas dans la base de données.

**Solutions possibles:**

#### Solution 1: Ajouter une propriété stockée (recommandé)

Modifier `EntityTransaction.swift` :

```swift
@Model final class EntityTransaction {
    // ... autres propriétés

    // Ajouter cette propriété stockée
    private var _cachedAmount: Double = 0.0

    // Changer amount en computed property qui utilise le cache
    var amount: Double {
        get { _cachedAmount }
        set { _cachedAmount = newValue }
    }

    // Mettre à jour le cache quand nécessaire
    func updateAmount() {
        _cachedAmount = sousOperations.reduce(0.0) { $0 + $1.amount }
    }
}
```

Puis dans le parser, utiliser `_cachedAmount` au lieu de `amount`.

#### Solution 2: Filtrer après le fetch

Ne pas filtrer sur `amount` dans le prédicat SwiftData, mais filtrer en mémoire après :

```swift
// Dans TransactionFilterViewModel
func applyPredicate(_ predicate: NSPredicate?) {
    // ... code existant

    // Si le prédicat contient "amount", filtrer en 2 temps
    if let pred = predicate, pred.predicateFormat.contains("amount") {
        // 1. Fetch toutes les transactions
        let descriptor = FetchDescriptor<EntityTransaction>(
            sortBy: [SortDescriptor(\.dateOperation, order: .reverse)]
        )
        let allTransactions = try modelContext.fetch(descriptor)

        // 2. Filtrer en mémoire avec NSPredicate
        filteredTransactions = allTransactions.filter { transaction in
            predicate.evaluate(with: ["amount": transaction.amount])
        }
    } else {
        // Utiliser le prédicat SwiftData normal
        // ... code existant
    }
}
```

#### Solution 3: Exclure `amount` du PredicateEditor

Retirer `amount` des templates dans `TransactionPredicateEditorView.swift` et utiliser seulement les champs stockés.

### 5. Autres champs problématiques possibles

Ces champs sont des **computed properties** et peuvent poser problème :

- `amount` (calculé depuis sousOperations)
- `statusString` (computed depuis status)
- `paymentModeString` (computed depuis paymentMode)
- `dateOperationString` (computed depuis dateOperation)
- `sectionIdentifier` (computed depuis datePointage)

**Pour ces champs, utilisez les propriétés de base :**
- ❌ Ne pas filtrer sur `statusString`
- ✅ Filtrer sur `status.name` à la place

### 6. Exemple de correction du parser

Si `statusString` pose problème, modifiez le parser :

```swift
// AVANT (dans predicateForString)
case "status":
    switch op {
    case "==": return #Predicate { $0.statusString == value }
    // ...

// APRÈS
case "status":
    switch op {
    case "==": return #Predicate { $0.status?.name == value }
    // ...
```

### 7. Test rapide

Pour tester rapidement, essayez avec un champ simple qui est **certainement stocké** :

1. `dateOperation` (Date stockée)
2. `datePointage` (Date stockée)
3. `bankStatement` (Double stocké)
4. `checkNumber` (String stocké)

Exemple de prédicat de test :
```
dateOperation > [Date d'aujourd'hui - 30 jours]
```

ou

```
bankStatement > 0
```

### 8. Récapitulatif des actions

1. ✅ Lancer l'app et regarder les logs
2. ✅ Identifier quel champ cause le problème
3. ✅ Vérifier si c'est une propriété calculée
4. ✅ Appliquer l'une des solutions ci-dessus
5. ✅ Retester

### 9. Me communiquer les logs

Si vous avez besoin d'aide, copiez-moi les logs de la console. Ils ressembleront à ceci :

```
🔍 Application du prédicat...
   → NSPredicate format: amount > 100
   [... suite des logs ...]
❌ Erreur de fetch : [Message d'erreur exact]
```

Avec ces informations, je pourrai vous aider précisément ! 🚀

---

## 🔧 Désactiver les logs en production

Une fois le problème résolu, vous pouvez désactiver les logs en ajoutant une condition :

```swift
#if DEBUG
print("🔍 Application du prédicat...")
#endif
```

Ou créer une fonction helper :

```swift
func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}
```
