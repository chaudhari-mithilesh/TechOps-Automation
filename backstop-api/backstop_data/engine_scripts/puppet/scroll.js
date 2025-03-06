module.exports = async (page, scenario, viewport) => {
    try {
      console.log("Starting scroll: scrolling down to the footer then back up to the header.");
  
      await page.evaluate(async () => {
        // Helper function to wait for a bit
        function sleep(ms) {
          return new Promise(resolve => setTimeout(resolve, ms));
        }
  
        // Scroll down until the footer is visible
        const footer = document.querySelector("footer");
        if (!footer) {
          console.error("Footer element not found on the page.");
          return;
        }
        let footerRect = footer.getBoundingClientRect();
        // Scroll until the top of the footer is visible in the viewport
        while (footerRect.top > window.innerHeight) {
          window.scrollBy(0, 100);
          await sleep(100);
          footerRect = footer.getBoundingClientRect();
        }
        console.log("Footer reached.");
        
        // Pause a moment at the bottom
        await sleep(1000);
  
        // Now scroll up until the header is fully visible
        const header = document.querySelector("header");
        if (!header) {
          console.error("Header element not found on the page.");
          return;
        }
        let headerRect = header.getBoundingClientRect();
        // Scroll up until the header's top is at or above 0 (visible)
        while (headerRect.top < 0) {
          window.scrollBy(0, -100);
          await sleep(100);
          headerRect = header.getBoundingClientRect();
        }
        console.log("Header reached.");
      });
  
      console.log("Scrolling operation completed.");
    } catch (error) {
      console.error("Error during scrolling:", error);
    }
  };
  