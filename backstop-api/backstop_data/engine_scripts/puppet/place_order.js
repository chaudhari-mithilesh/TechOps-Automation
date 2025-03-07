const { exec } = require("child_process");

module.exports = async (page, scenario, viewport) => {
    // Silence all browser console logs
    page.on('console', () => {});
    console.log("Running Place Order Test...");

    const isReference = scenario.url === scenario.referenceUrl;
    const currentUrl = isReference ? scenario.referenceUrl : scenario.url;
    const productUrl = isReference ? `${scenario.refProductUrl}/${scenario.refProductId}` : `${scenario.productUrl}/${scenario.productId}`;
    const productId = isReference ? scenario.refProductId : scenario.productId;

    function delay(time) {
        return new Promise(function(resolve) { 
            setTimeout(resolve, time)
        });
     }

    const username = '';
    const password = '';

    try {
        const waitForNetworkIdle = async () => {
            await page.waitForNavigation({ 
                waitUntil: 'networkidle0',
                timeout: 10000
            }).catch(() => console.log('Network idle timeout - continuing anyway'));
        };

        // Navigate to login page
        const loginUrl = new URL('/wp-login.php', currentUrl).href;
        console.log("Navigating to login page:", loginUrl);
        
        await page.goto(loginUrl);
        // await ensurePageLoaded();
        await waitForNetworkIdle();
        console.log("Login page loaded");

        // Login process
        await page.waitForSelector('input[name="log"]', { visible: true });
        await page.type('input[name="log"]', username);
        await page.type('input[name="pwd"]', password);
        
        await Promise.all([
        page.click('input[type="submit"]'),
        page.waitForNavigation({
            waitUntil: 'networkidle0',
            timeout: 15000
        })
        ]);
        console.log("Logged in successfully");

        try{
            await page.waitForSelector('.cookie-box__button', { 
                visible: true,
                timeout: 1000 
            });
            await page.$eval('.cookie-box__button', elem => elem.click());
            await new Promise(r => setTimeout(r, 3000));
            console.log("Cookie notice handled");
        } catch (e) {
        console.log("No cookie notice found");
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
            
            // // Run BackstopJS approve command
            // exec("backstop approve", (error, stdout, stderr) => {
            //     if (error) {
            //         console.error(`Error running backstop approve: ${error.message}`);
            //         return;
            //     }
            //     if (stderr) {
            //         console.error(`stderr: ${stderr}`);
            //         return;
            //     }
            //     console.log(`✅ Backstop approve executed successfully:\n${stdout}`);
            // });

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
            // Clear and fill in First Name
            console.log("Clearing and filling in '#billing_first_name' field...");
            await page.evaluate(() => {
                const el = document.querySelector('#billing_first_name');
                if (el) el.value = '';
            });
            await page.type('#billing_first_name', 'John');

            // Clear and fill in Last Name
            console.log("Clearing and filling in '#billing_last_name' field...");
            await page.evaluate(() => {
                const el = document.querySelector('#billing_last_name');
                if (el) el.value = '';
            });
            await page.type('#billing_last_name', 'Doe');

            // Clear and fill in Address
            console.log("Clearing and filling in '#billing_address_1' field...");
            await page.evaluate(() => {
                const el = document.querySelector('#billing_address_1');
                if (el) el.value = '';
            });
            await page.type('#billing_address_1', '123 Main St');

            // Clear and fill in City
            console.log("Clearing and filling in '#billing_city' field...");
            await page.evaluate(() => {
                const el = document.querySelector('#billing_city');
                if (el) el.value = '';
            });
            await page.type('#billing_city', 'New York');

            // Set State (select element)
            console.log("Selecting '#billing_state' field value...");
            await page.select('#billing_state', 'NY');

            // Clear and fill in Postcode
            console.log("Clearing and filling in '#billing_postcode' field...");
            await page.evaluate(() => {
                const el = document.querySelector('#billing_postcode');
                if (el) el.value = '';
            });
            await page.type('#billing_postcode', '10001');

            // Clear and fill in Phone
            console.log("Clearing and filling in '#billing_phone' field...");
            await page.evaluate(() => {
                const el = document.querySelector('#billing_phone');
                if (el) el.value = '';
            });
            await page.type('#billing_phone', '1234567890');

            // Clear and fill in Email
            console.log("Clearing and filling in '#billing_email' field...");
            await page.evaluate(() => {
                const el = document.querySelector('#billing_email');
                if (el) el.value = '';
            });
            await page.type('#billing_email', 'john.doe@example.com');

            console.log("Billing details filled successfully.");
        } catch (error) {
            console.error("❌ Error: Failed to fill in billing details.");
            await page.screenshot({ path: `error-billing-details-${Date.now()}.png`, fullPage: true });
            throw new Error("Billing details failed. Stopping execution.");
        }
        
        // Step 8: Check if COD Payment Method is Present
        // try {
        //     await page.waitForSelector('#payment_method_cod', { visible: true, timeout: 5000 });
        //     console.log("COD Payment Method found.");
        // } catch (error) {
        //     console.error("❌ Error: COD Payment Method not found.");
        //     await page.screenshot({ path: `error-cod-payment-${Date.now()}.png`, fullPage: true });
        //     throw new Error("COD Payment Method not found. Stopping execution.");
        // }

        // Step 9: Choose Payment Method (Cash on Delivery)
        // console.log("Choosing Payment Method");
        // await page.click('#payment_method_cod');

        // // Step 10: Place Order
        // console.log("Placing Order");
        // try {
        //     await page.click('#place_order');
        // } catch (error) {
        //     console.error("❌ Error: Failed to click 'Place Order' button.");
        //     await page.screenshot({ path: `error-place-order-${Date.now()}.png`, fullPage: true });
        //     throw new Error("Place Order failed. Stopping execution.");
        // }

        

        // // Wait for Order Confirmation
        // try {
        //     await page.waitForSelector('.woocommerce-order', { timeout: 20000 });
        //     console.log("Order placed successfully");
        // } catch (error) {
        //     console.error("❌ Error: Order confirmation not found.");
        //     console.error(error);
        //     await page.screenshot({ path: `error-order-confirmation-${Date.now()}.png`, fullPage: true });
        //     throw new Error("Order confirmation failed. Stopping execution.");
        // }
        
        // // Step 11: Validate Order Confirmation
        // const orderConfirmation = await page.$('.woocommerce-order');
        // if (orderConfirmation) {
        //     console.log(`✅ Test Passed: Order placed successfully!`);
        //     await page.screenshot({ path: `success-order-${Date.now()}.png`, fullPage: true });
        // } else {
        //     console.log(`❌ Test Failed: Order confirmation not found.`);
        //     await page.screenshot({ path: `error-order-${Date.now()}.png`, fullPage: true });
        //     throw new Error("Order confirmation not found. Stopping execution.");
        // }

        // Step 10: Place Order
        console.log("Step 10: Placing Order");

        try {
            // Check if the 'Place Order' button exists
            console.log("Checking if '#place_order' button exists...");
            await page.waitForSelector('#place_order', { visible: true, timeout: 5000 });
            console.log("✅ '#place_order' button found.");

            // Wait for 5 seconds before clicking the button
            console.log("Waiting for 5 seconds before clicking the 'Place Order' button...");
            await delay(15000);

            // Click on the 'Place Order' button
            console.log("Clicking on '#place_order' button...");
            await page.click('#place_order');
            console.log("Clicked on '#place_order' button. Waiting for navigation to complete...");

            // Wait for navigation after clicking
            await page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 20000 });
            console.log("Navigation complete. Waiting for order confirmation...");
        } catch (error) {
            console.log(error);
            console.error("❌ Error: Failed to click 'Place Order' button or navigation did not complete.");
            await page.screenshot({ path: `error-place-order-${Date.now()}.png`, fullPage: true });
            throw new Error("Place Order failed. Stopping execution.");
        }

        // Wait for Order Confirmation
        try {
            await page.waitForSelector('.woocommerce-order', { timeout: 10000 });
            console.log("Order placed successfully");
        } catch (error) {
            console.error("❌ Error: Order confirmation not found.");
            console.error(error);
            await page.screenshot({ path: `error-order-confirmation-${Date.now()}.png`, fullPage: true });
            throw new Error("Order confirmation failed. Stopping execution.");
        }
                
        // Step 11: Validate Order Confirmation
        const orderConfirmation = await page.$('.woocommerce-order');
        if (orderConfirmation) {
            console.log(`✅ Test Passed: Order placed successfully!`);
            await page.screenshot({ path: `success-order-${Date.now()}.png`, fullPage: true });
        } else {
            console.log(`❌ Test Failed: Order confirmation not found.`);
            await page.screenshot({ path: `error-order-${Date.now()}.png`, fullPage: true });
            throw new Error("Order confirmation not found. Stopping execution.");
        }

    } catch (error) {
        console.error('Checkout script error:', error);
        await page.screenshot({ path: `error-checkout-${Date.now()}.png`, fullPage: true });
        throw error;
    }
};