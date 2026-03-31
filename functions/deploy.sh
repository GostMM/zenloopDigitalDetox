#!/bin/bash

# Script de déploiement des Cloud Functions Firebase pour Zenloop
# Usage: ./deploy.sh [function_name]

set -e  # Arrêter en cas d'erreur

echo "🚀 Déploiement des Cloud Functions Firebase - Zenloop"
echo "══════════════════════════════════════════════════════"
echo ""

# Vérifier que Firebase CLI est installé
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI n'est pas installé"
    echo "📥 Installation: npm install -g firebase-tools"
    exit 1
fi

# Vérifier qu'on est dans le bon dossier
if [ ! -f "index.js" ]; then
    echo "❌ Erreur: Ce script doit être exécuté depuis le dossier functions/"
    exit 1
fi

# Vérifier la connexion Firebase
echo "🔍 Vérification de la connexion Firebase..."
if ! firebase projects:list &> /dev/null; then
    echo "❌ Non connecté à Firebase"
    echo "🔐 Exécutez: firebase login"
    exit 1
fi

# Afficher le projet actif
PROJECT=$(firebase use | grep "Active Project" | awk '{print $3}' || firebase use)
echo "✅ Projet actif: $PROJECT"
echo ""

# Installer les dépendances si nécessaire
if [ ! -d "node_modules" ]; then
    echo "📦 Installation des dépendances..."
    npm install
    echo ""
fi

# Fonction spécifique ou toutes les fonctions
if [ -n "$1" ]; then
    FUNCTION_NAME=$1
    echo "📤 Déploiement de la fonction: $FUNCTION_NAME"
    firebase deploy --only functions:$FUNCTION_NAME
else
    echo "📤 Déploiement de TOUTES les fonctions..."
    firebase deploy --only functions
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ Déploiement terminé !"
echo ""
echo "📊 Voir les logs:"
echo "   firebase functions:log"
echo ""
echo "🔍 Lister les fonctions:"
echo "   firebase functions:list"
echo ""
echo "🌐 Console Firebase:"
echo "   https://console.firebase.google.com/project/$PROJECT/functions"
echo "═══════════════════════════════════════════════════════"
