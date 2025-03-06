const express = require('express');
const { v4: uuidv4 } = require('uuid');
const bodyParser = require('body-parser');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
// app.use(bodyParser.json());
app.use(bodyParser.json({ limit: '100mb' }));

const jobs = new Map();

const backstopConfigTemplate = {
  id: "visual_regression_test",
  viewports: [],
  scenarios: [],
  paths: {
    bitmaps_reference: "backstop_data/bitmaps_reference",
    bitmaps_test: "backstop_data/bitmaps_test",
    ci_report: "backstop_data/ci_report",
    html_report: "backstop_data/html_report"
  },
  report: ["CI", "browser"],
  engine: "puppeteer",
  headless: true,
  asyncCaptureLimit: 5,
  asyncCompareLimit: 50,
  debug: false,
  debugWindow: false
};

// Create new Job

app.post('/api/visual-regression', (req, res) => {
  const {
    test: { testUrls, homeUrl: testHomeUrl, productUrl: testProductUrl, productId: testProductId },
    reference: { referenceUrls, homeUrl: refHomeUrl, productUrl: refProductUrl, productId: refProductId },
    devices
  } = req.body;
  console.log('Received request to start visual regression test');

  // Validation
  if (!testUrls || !Array.isArray(testUrls) || testUrls.length === 0) {
    return res.status(400).json({ error: 'Test URLs array is required' });
  }
  if (!referenceUrls || !Array.isArray(referenceUrls) || referenceUrls.length === 0) {
    return res.status(400).json({ error: 'Reference URLs array is required' });
  }
  if (testUrls.length !== referenceUrls.length) {
    return res.status(400).json({ error: 'Test URLs and Reference URLs arrays must have the same length' });
  }
  if (!devices || !Array.isArray(devices) || devices.length === 0) {
    return res.status(400).json({ error: 'Devices array is required' });
  }
  // if (!testHomeUrl || !testProductUrl || !testProductId) {
  //   return res.status(400).json({ error: 'Test homeUrl, productUrl, and productId are required' });
  // }
  // if (!refHomeUrl || !refProductUrl || !refProductId) {
  //   return res.status(400).json({ error: 'Reference homeUrl, productUrl, and productId are required' });
  // }

  // Generate a unique job ID
  const jobId = uuidv4();
  console.log(`Generated job ID: ${jobId}`);

  const config = { ...backstopConfigTemplate };
  config.id = `visual_regression_${jobId}`;
  config.report = ['CI'];

  // Set viewports from devices
  config.viewports = devices.map(device => ({
    label: device.name,
    width: device.width,
    height: device.height
  }));

  config.scenarios = testUrls.map((testUrl, index) => ({
    label: `Logged out Test ${testUrl}`,
    url: testUrl,
    referenceUrl: referenceUrls[index],
    onReadyScript: "puppet/add-to-cart.js",
    hideSelectors: [],
    removeSelectors: [],
    selectorExpansion: true,
    selectors: ['document'],
    readyEvent: null,
    readySelector: null,
    misMatchThreshold: 0.1,
    delay: 5000
  }));

  // login_scenario = config.scenarios.map(scenario => ({
  //   ...scenario,
  //   label: "Login Scenario",
  //   onReadyScript: "puppet/login.js"
  // }));

  // const addToCartScenario = [
  //   {
  //     label: "Add to Cart Test",
  //     url: testHomeUrl,
  //     referenceUrl: refHomeUrl,
  //     onReadyScript: "puppet/add-to-cart.js",
  //     selectors: ["document"],
  //     misMatchThreshold: 0.1,
  //     productUrl: testProductUrl, // Kept for script access if needed
  //     productId: testProductId,
  //     refProductUrl: refProductUrl,
  //     refProductId: refProductId,
  //     // delay: DEFAULT_DELAY
  //   }
  // ];

  // const cartActionsCouponScenario = [
  //   {
  //     label: "Cart Actions Coupon Test",
  //     url: testHomeUrl,
  //     referenceUrl: refHomeUrl,
  //     onReadyScript: "puppet/cart_actions_coupon.js",
  //     selectors: ["document"],
  //     misMatchThreshold: 0.1,
  //     productUrl: testProductUrl,
  //     productId: testProductId,
  //     refProductUrl: refProductUrl,
  //     refProductId: refProductId,
  //     // delay: DEFAULT_DELAY
  //   }
  // ];

  // const cartActionsQtyScenario = [
  //   {
  //     label: "Cart Actions Change Quantity Test",
  //     url: testHomeUrl,
  //     referenceUrl: refHomeUrl,
  //     onReadyScript: "puppet/cart_actions_change_qty.js",
  //     selectors: ["document"],
  //     misMatchThreshold: 0.1,
  //     productUrl: testProductUrl,
  //     productId: testProductId,
  //     refProductUrl: refProductUrl,
  //     refProductId: refProductId,
  //     // delay: DEFAULT_DELAY
  //   }
  // ];

  // const cartActionsRemoveScenario = [
  //   {
  //     label: "Cart Actions Remove Test",
  //     url: testHomeUrl,
  //     referenceUrl: refHomeUrl,
  //     onReadyScript: "puppet/cart_actions_remove.js",
  //     selectors: ["document"],
  //     misMatchThreshold: 0.1,
  //     productUrl: testProductUrl,
  //     productId: testProductId,
  //     refProductUrl: refProductUrl,
  //     refProductId: refProductId,
  //     // delay: DEFAULT_DELAY
  //   }
  // ];

  // const checkoutScenario = [
  //   {
  //     label: "Checkout Test",
  //     url: testHomeUrl,
  //     referenceUrl: refHomeUrl,
  //     onReadyScript: "puppet/checkout.js",
  //     selectors: ["document"],
  //     misMatchThreshold: 0.1,
  //     productUrl: testProductUrl,
  //     productId: testProductId,
  //     refProductUrl: refProductUrl,
  //     refProductId: refProductId,
  //     // delay: DEFAULT_DELAY
  //   }
  // ];

  // const placeOrderScenario = [
  //   {
  //     label: "Place Order Test",
  //     url: testHomeUrl,
  //     referenceUrl: refHomeUrl,
  //     onReadyScript: "puppet/place_order.js",
  //     selectors: ["document"],
  //     misMatchThreshold: 0.1,
  //     productUrl: testProductUrl,
  //     productId: testProductId,
  //     refProductUrl: refProductUrl,
  //     refProductId: refProductId,
  //     // delay: DEFAULT_DELAY
  //   }
  // ];

  // config.scenarios = [
  //   ...config.scenarios,
  //   ...login_scenario,
  //   ...addToCartScenario,
  //   ...cartActionsCouponScenario,
  //   ...cartActionsQtyScenario,
  //   ...cartActionsRemoveScenario,
  //   ...checkoutScenario,
  //   ...placeOrderScenario
  // ];

  const configPath = path.join(__dirname, `backstop-${jobId}.json`);
  console.log(`Config file path: ${configPath}`);
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

  jobs.set(jobId, {
    status: 'pending',
    configPath,
    timeStarted: new Date(),
    results: null,
    error: null
  });

  res.json({
    jobId,
    status: 'pending',
    message: 'Visual regression test job created'
  });
  // runBackstopJS(jobId, config, configReference);

});

// Run Reference Process

app.post('/api/visual-regression/reference/:jobId', (req, res) => {
  const { jobId } = req.params;
  const job = jobs.get(jobId);

  if (!job) {
    return res.status(404).json({ error: 'Job not found' });
  }

  if (job.status !== 'pending' && job.status !== 'test_completed') {
    return res.status(400).json({ error: 'Job is not in a state to run reference' });
  }

  job.status = 'reference_running';
  const configPath = job.configPath;

  const referenceProcess = spawn('backstop', ['reference', '--config', configPath]);

  referenceProcess.stdout.on('data', (data) => {
    console.log(`BackstopJS Reference: ${data.toString()}`);
  });

  referenceProcess.stderr.on('data', (data) => {
    console.error(`BackstopJS Reference Error: ${data.toString()}`);
  });

  referenceProcess.on('close', (code) => {
    if (code === 0) {
      job.status = 'reference_completed';
    } else {
      job.status = 'failed';
      job.error = 'Failed to create reference images';
    }
  });

  res.json({ jobId, status: job.status, message: 'Reference process started' });
});

// Run Test Process

app.post('/api/visual-regression/test/:jobId', (req, res) => {
  const { jobId } = req.params;
  const job = jobs.get(jobId);

  if (!job) {
    return res.status(404).json({ error: 'Job not found' });
  }

  if (job.status !== 'reference_completed') {
    return res.status(400).json({ error: 'Reference must be completed before running test' });
  }

  job.status = 'test_running';
  const configPath = job.configPath;

  const testProcess = spawn('backstop', ['test', '--config', configPath]);

  testProcess.stdout.on('data', (data) => {
    console.log(`BackstopJS Test: ${data.toString()}`);
  });

  testProcess.stderr.on('data', (data) => {
    console.error(`BackstopJS Test Error: ${data.toString()}`);
  });

  testProcess.on('close', (code) => {
    if (code === 0) {
      try {
        const reportPath = path.join(__dirname, `backstop_data/ci_report/${config.id}/xunit.xml`);
        const results = fs.readFileSync(reportPath, 'utf8');
        job.status = 'completed';
        job.results = results;
      } catch (error) {
        job.status = 'failed';
        job.error = 'Failed to read test results';
      }
    } else {
      job.status = 'failed';
      job.error = 'Test comparison failed';
    }
  });

  res.json({ jobId, status: job.status, message: 'Test process started' });
});

// Get Job Status

app.get('/api/visual-regression/:jobId', (req, res) => {
  const { jobId } = req.params;
  const job = jobs.get(jobId);

  if (!job) {
    return res.status(404).json({ error: 'Job not found' });
  }

  res.json({
    jobId,
    status: job.status,
    timeStarted: job.timeStarted,
    results: job.results
  });
});

// function runBackstopJS(jobId, config, configReference) {
//   const job = jobs.get(jobId);
//   console.log(`Starting BackstopJS reference for job ID: ${jobId}`);

//   const configPath = path.join(__dirname, 'backstop-test.json');
//   const referenceConfigPath = path.join(__dirname, 'backstop-reference.json');
//   console.log(`Config file path: ${configPath}`);
//   require('fs').writeFileSync(configPath, JSON.stringify(config, null, 2));
//   require('fs').writeFileSync(referenceConfigPath, JSON.stringify(configReference, null, 2));

//   // Variables to store output for the reference process
//   let referenceStdout = '';
//   let referenceStderr = '';

//   const referenceProcess = spawn('backstop', ['reference', '--config', referenceConfigPath, '--verbose']);

//   referenceProcess.stdout.on('data', (data) => {
//     const output = data.toString();
//     console.log(`BackstopJS: ${output}`);
//     referenceStdout += output;
//   });

//   referenceProcess.stderr.on('data', (data) => {
//     const errorData = data.toString();
//     console.error(`BackstopJS error: ${errorData}`);
//     referenceStderr += errorData;
//   });

//   referenceProcess.on('error', (err) => {
//     console.error(`Failed to start BackstopJS reference process: ${err.message}`);
//     jobs.set(jobId, {
//       ...job,
//       status: 'failed',
//       error: `Failed to start reference process: ${err.message}`
//     });
//   });

//   referenceProcess.on('close', (code) => {
//     console.log(`BackstopJS reference process exited with code: ${code}`);
//     if (code !== 0) {
//       const errorMessage = referenceStderr.trim() || referenceStdout.trim() || 'Failed to create reference images';
//       jobs.set(jobId, {
//         ...job,
//         status: 'failed',
//         error: errorMessage
//       });
//       console.error(`Error: ${errorMessage}`);
//       return;
//     }

//     // Variables to store output for the test process
//     let testStdout = '';
//     let testStderr = '';

//     const testProcess = spawn('backstop', ['test', '--config', configPath, '--verbose']);
//     console.log(`Starting BackstopJS test process for job ID: ${jobId}`);

//     testProcess.stdout.on('data', (data) => {
//       const output = data.toString();
//       console.log(`BackstopJS: ${output}`);
//       testStdout += output;
//     });

//     testProcess.stderr.on('data', (data) => {
//       const errorData = data.toString();
//       console.error(`BackstopJS error: ${errorData}`);
//       testStderr += errorData;
//     });

//     testProcess.on('error', (err) => {
//       console.error(`Failed to start BackstopJS test process: ${err.message}`);
//       jobs.set(jobId, {
//         ...job,
//         status: 'failed',
//         error: `Failed to start test process: ${err.message}`
//       });
//     });

//     testProcess.on('close', (code) => {
//       require('fs').unlinkSync(configPath);
//       console.log(`[Job ${jobId}] BackstopJS test process exited with code: ${code}`);

//       if (code !== 0) {
//         const errorMessage = testStderr.trim() || testStdout.trim() || 'Test comparison failed';
//         jobs.set(jobId, {
//           ...job,
//           status: 'failed',
//           error: errorMessage
//         });
//         console.error(`[Job ${jobId}] Error: ${errorMessage}`);
//         return;
//       }

//       try {
//         console.log(`[Job ${jobId}] Reading test results`);
//         const results = require('fs').readFileSync(
//           path.join(__dirname, 'backstop_data/ci_report/xunit.xml'),
//           'utf8'
//         );

//         jobs.set(jobId, {
//           ...job,
//           status: 'completed',
//           results: results
//         });
//       } catch (error) {
//         jobs.set(jobId, {
//           ...job,
//           status: 'failed',
//           error: `Failed to read test results: ${error.message}`
//         });
//         console.error(`[Job ${jobId}] Error reading test results: ${error.message}`);
//       }
//     });
//   });
// }

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API running on port ${PORT}`);
});