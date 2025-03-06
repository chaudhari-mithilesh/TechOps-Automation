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

        // Apply Coupon
        console.log("Applying coupon code 'AUTOMATIONTESTINGCOUPON100'...");
        await page.waitForSelector('#coupon_code', { visible: true, timeout: 5000 });
        // Clear any existing coupon code value
        await page.evaluate(() => {
            const couponInput = document.querySelector('#coupon_code');
            if (couponInput) couponInput.value = '';
        });
        await page.type('#coupon_code', 'AUTOMATIONTESTINGCOUPON100');
        // Click the "Apply Coupon" button; update the selector if needed
        await page.click('button[name="apply_coupon"]');
        // Wait for a confirmation message that the coupon was applied
        await page.waitForSelector('.woocommerce-message', { timeout: 10000 });
        console.log("Coupon applied successfully.");
            

    } else {
        console.error(`❌ Product ID ${productId} NOT found in cart!`);
    }

    console.log(`Test Completed for - "${scenario.label}"`);
};