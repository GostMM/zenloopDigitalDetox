#!/bin/bash

echo "🧪 Testing StoreKit Configuration for Zenloop"
echo "=============================================="

# Check if Products.storekit exists
echo "📁 Checking if Products.storekit exists..."
if [ -f "zenloop/StoreKit/Products.storekit" ]; then
    echo "✅ Products.storekit found"
else
    echo "❌ Products.storekit NOT found"
    exit 1
fi

# Check subscriptions in StoreKit file
echo ""
echo "📦 Checking product IDs in StoreKit file..."
if grep -q "com.app.zenloop.premium.monthly" zenloop/StoreKit/Products.storekit; then
    echo "✅ Monthly subscription found"
else
    echo "❌ Monthly subscription NOT found"
fi

if grep -q "com.app.zenloop.premium.yearly" zenloop/StoreKit/Products.storekit; then
    echo "✅ Yearly subscription found"
else
    echo "❌ Yearly subscription NOT found"
fi

# Check for StoreKit errors
echo ""
echo "⚠️  Checking for StoreKit test errors..."
if grep -q '"enabled" : true' zenloop/StoreKit/Products.storekit; then
    echo "❌ StoreKit errors are ENABLED - this will prevent product loading!"
    echo "   Disable them in Xcode StoreKit Configuration Editor"
else
    echo "✅ No StoreKit errors enabled"
fi

# Check project configuration
echo ""
echo "🎯 Next steps to check in Xcode:"
echo "1. Product → Scheme → Edit Scheme..."
echo "2. Run → Options tab"
echo "3. StoreKit Configuration: Select 'Products.storekit'"
echo "4. Build and run the app"
echo "5. Check Console for logs starting with 🛒 📦 💰"

echo ""
echo "🏁 Test complete!"