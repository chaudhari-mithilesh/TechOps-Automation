const { exec } = require("child_process");

module.exports = async (page, scenario, viewport) => {
    // Silence all browser console logs
    page.on('console', () => {});
    console.log("Running Add to Cart Test...");

    const isReference = scenario.url === scenario.referenceUrl;
    const currentUrl = isReference ? scenario.referenceUrl : scenario.url;
    const productUrl = isReference ? `${scenario.refProductUrl}` : `${scenario.productUrl}`;
    const productId = isReference ? scenario.refProductId : scenario.productId;

    function delay(time) {
        return new Promise(function(resolve) { 
            setTimeout(resolve, time)
        });
    }

    try {
        const waitForNetworkIdle = async () => {
            await page.waitForNavigation({ 
                waitUntil: 'networkidle0',
                timeout: 10000
            }).catch(() => console.log('Network idle timeout - continuing anyway'));
        };

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

        } else {
            console.error(`❌ Product ID ${productId} NOT found in cart!`);
            await page.screenshot({ path: `error-cart-${Date.now()}.png`, fullPage: true });
            throw new Error("Product not found in cart. Stopping execution.");
        }

        console.log("Add to Cart Test Completed!");

        // Step 6: Proceed to Checkout
        const checkoutURL = `${currentUrl}/checkout`;
        console.log("Navigating to Checkout Page:", checkoutURL);
        await page.goto(checkoutURL, { waitUntil: 'networkidle2' });
        await waitForNetworkIdle();
        
        // Step 7: Fill in Billing Details
        console.log("Filling in Billing Details");
        try {
            await page.type('#billing_first_name', 'John');
            await page.type('#billing_last_name', 'Doe');
            await page.type('#billing_address_1', '123 Main St');
            await page.type('#billing_city', 'New York');
            await page.select('#billing_state', 'NY');
            await page.type('#billing_postcode', '10001');
            await page.type('#billing_phone', '1234567890');
            await page.type('#billing_email', 'john.doe@example.com');
            await delay(10000);
        } catch (error) {
            console.error("❌ Error: Failed to fill in billing details.");
            await page.screenshot({ path: `error-billing-details-${Date.now()}.png`, fullPage: true });
            throw new Error("Billing details failed. Stopping execution.");
        }
    } catch (error) {
        console.error('Checkout script error:', error);
        await page.screenshot({ path: `error-checkout-${Date.now()}.png`, fullPage: true });
        throw error;
    }
};