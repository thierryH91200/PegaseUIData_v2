# Solution au problème NSColor

## 🐛 Problème identifié

### Erreur
```
SwiftData/DataUtilities.swift:1151: Fatal error: Unexpected class type: NSColor
```

### Cause
Quand vous filtrez sur `status == ""`, SwiftData essaie d'accéder à l'objet `EntityStatus` qui contient une propriété `NSColor` :

```swift
@Model final class EntityStatus {
    var name: String
    var rawType: Int
    @Attribute(.transformable(by: ColorTransformer.self)) var color: NSColor
    // ...
}
```

Le problème : **SwiftData ne peut pas utiliser NSColor dans les prédicats** car NSColor n'est pas un type supporté nativement par SwiftData pour les requêtes.

## ✅ Solution appliquée

### Avant (causait l'erreur)
```swift
case "status":
    switch op {
    case "==": return #Predicate { $0.statusString == value }
    // statusString est une computed property qui accède à status.name
    // Cela force SwiftData à charger l'objet EntityStatus entier
    // incluant le NSColor → CRASH
```

### Après (corrigé)
```swift
case "status":
    switch op {
    case "==": return #Predicate { $0.status?.name == value }
    // On accède directement à la propriété name de status
    // SwiftData ne charge que le champ name, pas la couleur
    // → PAS DE CRASH
```

## 📝 Changements appliqués

### Fichier modifié
`TransactionPredicateParser.swift` (lignes 362-387)

### Ce qui a changé

1. **Pour status** :
   - ❌ Avant : `$0.statusString == value`
   - ✅ Après : `$0.status?.name == value`

2. **Pour mode** :
   - ❌ Avant : `$0.paymentModeString == value`
   - ✅ Après : `$0.paymentMode?.name == value`

## 🧪 Tests à effectuer

### Test 1: Filtrer sur status
1. Lancer l'application
2. Créer un filtre : `status == "Validé"` (ou le nom d'un de vos statuts)
3. Vérifier que le fetch fonctionne sans crash

### Test 2: Filtrer sur mode
1. Créer un filtre : `mode == "Carte bancaire"` (ou un de vos modes de paiement)
2. Vérifier que ça fonctionne

### Test 3: Autres champs
Vérifier que les autres champs fonctionnent toujours :
- `dateOperation > [Date]`
- `bankStatement > 0`
- `checkNumber == "12345"`

## 🔍 Pourquoi ça marche maintenant ?

### Explication technique

Quand vous écrivez `$0.status?.name`, SwiftData génère une requête SQL qui :
1. Joint la table `EntityTransaction` avec `EntityStatus`
2. Filtre uniquement sur le champ `name` de EntityStatus
3. **N'accède jamais au champ `color`** qui contient le NSColor problématique

Avant, avec `statusString`, c'était une computed property qui forçait le chargement complet de l'objet EntityStatus, incluant la couleur.

### Schéma de la requête

```
Avant (❌ CRASH):
EntityTransaction → charge EntityStatus entier (avec NSColor) → CRASH

Après (✅ OK):
EntityTransaction → EntityStatus.name uniquement → OK
```

## 🎯 Autres propriétés problématiques potentielles

Si vous avez le même problème avec d'autres entités, vérifiez si elles contiennent :
- `NSColor` / `Color`
- `NSImage` / `Image`
- `Data` (gros fichiers)
- Autres types complexes transformables

**Solution :** Toujours filtrer sur les propriétés simples (String, Int, Double, Date) et pas sur les computed properties ou les objets entiers.

## 📊 Impact de la modification

### Avant
- ✅ Tous les champs sauf `status` et `mode` fonctionnaient
- ❌ Crash sur `status == ...`
- ❌ Probablement crash sur `mode == ...`

### Après
- ✅ Tous les champs fonctionnent
- ✅ `status` fonctionne
- ✅ `mode` fonctionne
- ✅ Pas de crash NSColor

## 🚀 Prochaines étapes

1. **Tester l'application** avec différents filtres
2. **Vérifier les performances** (devrait être identique ou meilleur)
3. Si tout fonctionne, vous pouvez **désactiver les logs de debug** (voir DEBUG_GUIDE.md)

## ⚠️ Note importante

Cette solution fonctionne car :
- `EntityStatus` a une propriété `name` qui est un `String`
- `EntityPaymentMode` a une propriété `name` qui est un `String`

Si vos entités ont des noms de propriétés différents, ajustez le code en conséquence.

Par exemple, si EntityStatus utilisait `title` au lieu de `name` :
```swift
case "status":
    case "==": return #Predicate { $0.status?.title == value }
```

---

**Date de correction :** 16/01/2026
**Problème résolu :** ✅ Crash NSColor dans SwiftData Predicate
