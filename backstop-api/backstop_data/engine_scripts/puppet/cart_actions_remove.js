const { exec } = require("child_process");

module.exports = async (page, scenario, viewport) => {
    // Silence all browser console logs
    page.on('console', () => {});
    // console.log("Running Add to Cart Test...");
    const testType = scenario.label.toLowerCase();
    console.log(`Running multi-step flow test. Scenario: "${scenario.label}"`);

    const isReference = scenario.url === scenario.referenceUrl;
    const currentUrl = isReference ? scenario.referenceUrl : scenario.url;
    const productUrl = isReference ? `${scenario.refProductUrl}` : `${scenario.productUrl}`;
    const productId = isReference ? scenario.refProductId : scenario.productId;

    function delay(time) {
        return new Promise(function(resolve) { 
            setTimeout(resolve, time)
        });
     }
  
    await page.goto(productUrl, { waitUntil: "networkidle2" });
  
    // Click 'Add to Cart'
    await page.waitForSelector(".single_add_to_cart_button", { visible: true });
    await page.click(".single_add_to_cart_button");
  
    // Wait for cart update
    await page.waitForSelector(".woocommerce-message", { timeout: 10000 });
    console.log("Add to Cart Button Clicked!");

    // Navigate to the cart page
    await page.goto(`${currentUrl}/cart`, { waitUntil: "networkidle2" });

    // Extract product IDs from the cart
    const cartProductIds = await page.evaluate(() => {
        return [...document.querySelectorAll(".remove[data-product_id]")].map(
            (item) => item.getAttribute("data-product_id")
        );
    });

    console.log(`Cart ProductIds - ${cartProductIds}`);

    // Check if the expected product ID is in the cart
    if (cartProductIds.includes(productId)) {
        console.log(`✅ Product ID ${productId} found in cart!`);

        // Remove Product
        try {
            console.log("Removing product from cart...");
            // Wait until the remove button is present in the DOM (not forcing visibility)
            await page.waitForSelector('.remove', { timeout: 15000 });
            console.log("✅ Remove button found. Attempting to click it using evaluate...");
        
            // Use page.evaluate to click the remove button, bypassing potential clickability issues
            await page.evaluate(() => {
                const removeBtn = document.querySelector('.remove');
                if (removeBtn) {
                    removeBtn.click();
                } else {
                    throw new Error("Remove button not found in DOM during evaluation.");
                }
            });
        
            // Wait until the remove button is no longer present in the DOM to confirm removal
            await page.waitForFunction(() => !document.querySelector('.remove'), { timeout: 10000 });
            console.log("Product removed from cart successfully.");
        } catch (error) {
            console.error("❌ Error: Failed to remove product from cart.", error);
            await page.screenshot({ path: `error-remove-product-${Date.now()}.png`, fullPage: true });
            throw new Error("Product removal failed. Stopping execution.");
        }
            

    } else {
        console.error(`❌ Product ID ${productId} NOT found in cart!`);
    }

    console.log(`Test Completed for - "${scenario.label}"`);
};