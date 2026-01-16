# Guide de démarrage rapide - NSPredicateEditor pour EntityTransaction

## 🚀 Utilisation la plus simple

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        TransactionFilterView()
    }
}
```

C'est tout ! Vous avez maintenant une interface complète avec :
- ✅ NSPredicateEditor pour construire des filtres
- ✅ Liste des transactions filtrées
- ✅ Conversion automatique NSPredicate → SwiftData
- ✅ Statistiques et bouton d'effacement

---

## 📋 Fichiers créés

1. **TransactionPredicateParser.swift** - Parse NSPredicate → SwiftData Predicate
2. **TransactionPredicateEditorView.swift** - Vue SwiftUI pour NSPredicateEditor
3. **TransactionFilterView.swift** - Vue complète prête à l'emploi
4. **ExampleUsage.swift** - 4 exemples d'utilisation
5. **QUICKSTART.md** - Ce fichier

---

## 🔍 Champs disponibles

| Champ | Type | Exemple |
|-------|------|---------|
| `amount` | Double | `amount > 100` |
| `bankStatement` | Double | `bankStatement >= 1000` |
| `dateOperation` | Date | `dateOperation > "2024-01-01"` |
| `datePointage` | Date | `datePointage >= Date()` |
| `status` | String | `status == "Validé"` |
| `mode` | String | `mode == "Carte bancaire"` |
| `checkNumber` | String | `checkNumber == "12345"` |

---

## 💡 Exemples d'utilisation

### 1. Vue complète (le plus simple)

```swift
TransactionFilterView()
```

### 2. Avec binding personnalisé

```swift
struct MyView: View {
    @State private var predicate: NSPredicate?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TransactionPredicateEditorView(
            predicate: $predicate,
            onPredicateChange: handleChange
        )
    }

    func handleChange(_ newPredicate: NSPredicate?) {
        // Votre logique ici
    }
}
```

### 3. Parser seul

```swift
// Créer un NSPredicate
let nsPredicate = NSPredicate(format: "amount > 100")

// Convertir en SwiftData Predicate
let swiftDataPredicate = TransactionPredicateParser.swiftDataPredicate(
    from: nsPredicate
)

// Utiliser dans un FetchDescriptor
let descriptor = FetchDescriptor<EntityTransaction>(
    predicate: swiftDataPredicate
)

let transactions = try modelContext.fetch(descriptor)
```

### 4. Validation d'un prédicat

```swift
do {
    try PredicateEditorValidator.validate(nsPredicate)
    print("✅ Prédicat valide")
} catch {
    print("❌ Erreur: \(error.localizedDescription)")
}
```

---

## 🎯 Exemples de filtres

### Par montant
```
amount > 100
amount >= 50 AND amount <= 200
```

### Par date
```
dateOperation > "2024-01-01"
datePointage >= Date()
```

### Par statut
```
status == "Validé"
mode == "Carte bancaire"
```

### Combinaisons
```
amount > 100 AND dateOperation > "2024-01-01"
status == "Validé" OR status == "En attente"
```

---

## 📦 Intégration dans votre code

### Option A: Remplacer HybridContentView

Si vous utilisez actuellement `HybridContentView` :

```swift
// AVANT
HybridContentView(dashboard: $dashboard)

// APRÈS
TransactionFilterView()
```

### Option B: Intégrer dans une vue existante

```swift
struct MyExistingView: View {
    @State private var predicate: NSPredicate?

    var body: some View {
        VStack {
            TransactionPredicateEditorView(
                predicate: $predicate,
                onPredicateChange: { _ in }
            )

            // Votre contenu existant
            MyTransactionList(predicate: predicate)
        }
    }
}
```

---

## ✅ Checklist d'intégration

- [ ] Les 3 fichiers principaux sont dans le projet (.swift)
- [ ] `Validator.swift` existe déjà (validation)
- [ ] `NSPredicateEditorRowTemplate.swift` existe déjà (templates)
- [ ] Le projet compile sans erreurs
- [ ] Testé avec un filtre simple : `amount > 100`
- [ ] Testé avec un filtre composé : `amount > 100 AND status == "Validé"`

---

## 🐛 Problèmes courants

### Erreur "missing import of defining module 'Combine'"

**Solution :** Vérifier que les imports sont présents :
```swift
import SwiftUI
import SwiftData
import Combine  // ← Important pour @Published
```

### Le filtre ne fonctionne pas

**Solution :**
1. Vérifier que les noms de champs sont corrects
2. Utiliser le validateur : `try PredicateEditorValidator.validate(predicate)`
3. Afficher le format : `print(predicate.predicateFormat)`

### Performance lente avec beaucoup de données

**Solution :**
- Utiliser `FetchDescriptor` avec le prédicat (pas de filtre en mémoire)
- Ajouter des index SwiftData sur les champs fréquemment filtrés

---

## 📚 Documentation complète

Pour plus d'informations, consultez les fichiers de documentation complets créés précédemment :
- `README_TransactionFilter.md` - Guide complet
- `SUMMARY.md` - Vue d'ensemble
- `ARCHITECTURE.md` - Architecture détaillée
- `MIGRATION_GUIDE.md` - Guide de migration

---

## 🎉 C'est prêt !

Votre module de filtrage est maintenant opérationnel. Lancez l'application et testez avec différents filtres !

Pour des exemples plus avancés, consultez `ExampleUsage.swift`.
