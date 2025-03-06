// puppet/login.js
module.exports = async (page, scenario, viewport) => {
  // Silence all browser console logs
  page.on('console', () => {});
  console.log(`SCENARIO > ${scenario.label}`);
  console.log(`VIEWPORT > ${viewport.label}`);

  const isReference = scenario.url === scenario.referenceUrl;
  const currentUrl = isReference ? scenario.referenceUrl : scenario.url;

  // if (scenario.isReference) currentUrl = scenario.referenceUrl;
  
  const username = '';
  const password = '';

  try {
    // Helper function to wait for network idle
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

    // Store cookies after login
    // const cookies = await page.cookies();
    // console.log("Cookies stored after login:", cookies);
    // console.log("Cookies stored after login.");

    // Filter relevant WordPress authentication cookies
  // const authCookies = cookies.filter(cookie => 
  //   cookie.name.startsWith('wordpress_logged_in_') || 
  //   cookie.name.startsWith('wp-settings-')
  // );

  // console.log('Filtered WordPress Cookies:', authCookies);
    // Handle cookie notice (if present)
    try {
      // await page.waitForSelector('.ch2-allow-all-btn', { 
      //   visible: true,
      //   timeout: 5000
      // });
      // await page.$eval('.ch2-allow-all-btn', elem => elem.click());
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

    // Navigate to test URL
    console.log("Navigating to test URL:", currentUrl);
    await page.goto(currentUrl + '?test');
    // await ensurePageLoaded();
    await waitForNetworkIdle();
    
    // Restore cookies for the test page
    // console.log("Cookies to be restored", cookies);
    // await page.setCookie(...cookies);
    // console.log("Cookies restored on test page");

    // // Additional checks to ensure page is ready
    // await Promise.all([ 
    //   page.waitForFunction(() => {
    //     const images = document.getElementsByTagName('img');
    //     return Array.from(images).every(img => img.complete);
    //   }),
    //   page.waitForFunction(() => {
    //     return !document.querySelector('.loading, .loader, .spinner');
    //   }).catch(() => console.log('No loader found')),
    // ]);

    // // Final wait to ensure stability
    // await new Promise(r => setTimeout(r, 2000));
    // console.log("Page fully loaded and stable");

  } catch (error) {
    console.error('Login script error:', error);
    await page.screenshot({
      path: `error-${Date.now()}.png`,
      fullPage: true
    });
    throw error;
  }
};
