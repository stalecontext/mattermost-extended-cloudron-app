#!/usr/bin/env node

/* jshint esversion: 8 */
/* global it, xit, describe, before, after, afterEach */

'use strict';

require('chromedriver');

const execSync = require('child_process').execSync,
    fs = require('fs'),
    expect = require('expect.js'),
    path = require('path'),
    { Builder, By, Key, until } = require('selenium-webdriver'),
    { Options } = require('selenium-webdriver/chrome');

if (!process.env.USERNAME || !process.env.PASSWORD || !process.env.EMAIL) {
    console.log('USERNAME, EMAIL and PASSWORD env vars need to be set');
    process.exit(1);
}

describe('Application life cycle test', function () {
    this.timeout(0);

    const LOCATION = process.env.LOCATION || 'test';
    const TEST_TIMEOUT = parseInt(process.env.TIMEOUT, 10) || 30000;

    const TEST_MESSAGE = 'Hello Test!';
    const DEFAULT_CHANNEL = 'town-square';
    const TEST_TEAM = 'cloudron';
    const EXEC_ARGS = { cwd: path.resolve(__dirname, '..'), stdio: 'inherit' };
    const appManifest = require('../CloudronManifest.json');

    var browser;
    var app;
    const username = process.env.USERNAME;
    const password = process.env.PASSWORD;
    const email = process.env.EMAIL;

    before(function () {
        const chromeOptions = new Options().windowSize({ width: 1280, height: 1024 });
        if (process.env.CI) chromeOptions.addArguments('no-sandbox', 'disable-dev-shm-usage', 'headless');
        browser = new Builder().forBrowser('chrome').setChromeOptions(chromeOptions).build();
        if (!fs.existsSync('./screenshots')) fs.mkdirSync('./screenshots');
    });

    after(function () {
        browser.quit();
    });

    afterEach(async function () {
        if (!process.env.CI || !app) return;

        const currentUrl = await browser.getCurrentUrl();
        if (!currentUrl.includes(app.domain)) return;
        expect(this.currentTest.title).to.be.a('string');

        const screenshotData = await browser.takeScreenshot();
        fs.writeFileSync(`./screenshots/${new Date().getTime()}-${this.currentTest.title.replaceAll(' ', '_')}.png`, screenshotData, 'base64');
    });

    async function clearCache() {
        await browser.manage().deleteAllCookies();
        await browser.quit();
        browser = null;
        const chromeOptions = new Options().windowSize({ width: 1280, height: 1024 });
        if (process.env.CI) chromeOptions.addArguments('no-sandbox', 'disable-dev-shm-usage', 'headless');
        chromeOptions.addArguments(`--user-data-dir=${await fs.promises.mkdtemp('/tmp/test-')}`); // --profile-directory=Default
        browser = new Builder().forBrowser('chrome').setChromeOptions(chromeOptions).build();
    }

    function getAppInfo() {
        const inspect = JSON.parse(execSync('cloudron inspect'));
        app = inspect.apps.filter(function (a) { return a.location === LOCATION || a.location === LOCATION + '2'; })[0];
        expect(app).to.be.an('object');
    }

    async function waitForElement(elem) {
        await browser.wait(until.elementLocated(elem), TEST_TIMEOUT);
        await browser.wait(until.elementIsVisible(browser.findElement(elem)), TEST_TIMEOUT);
    }

    function waitForPath(path) {
        return browser.wait(function () {
            return browser.getCurrentUrl().then(function (currentUrl) {
                return currentUrl === `https://${app.fqdn}${path}`;
            });
        });
    }

    async function login() {
        await browser.get(`https://${app.fqdn}/login`);
        await waitForElement(By.id('input_loginId'));
        await waitForElement(By.name('password-input'));

        await browser.findElement(By.id('input_loginId')).sendKeys(username);
        await browser.findElement(By.name('password-input')).sendKeys(password);
        await browser.findElement(By.xpath('//button[@type="submit"]')).click();

        await waitForElement(By.xpath('//span[text()="Town Square"]'));
    }

    // this appears randomly
    async function closeTutorialTip() {
        await browser.get(`https://${app.fqdn}/${TEST_TEAM}/channels/${DEFAULT_CHANNEL}`);
        try {
            await browser.wait(until.elementLocated(By.xpath('//button[@data-test-id="close_tutorial_tip"]')), 3000);
            await browser.findElement(By.xpath('//button[@data-test-id="close_tutorial_tip"]')).click();
            await browser.sleep(3000);
        } catch (e) {
            console.log('there was no tutorial tip, ignoring');
        }
    }

    async function sendMessage() {
        await browser.get(`https://${app.fqdn}/${TEST_TEAM}/channels/${DEFAULT_CHANNEL}`);
        await waitForElement(By.id('post_textbox'));
        await browser.findElement(By.id('post_textbox')).sendKeys(TEST_MESSAGE);
        await browser.sleep(2000);
        await waitForElement(By.id('post_textbox'));
        await browser.findElement(By.id('post_textbox')).sendKeys(Key.RETURN);
        await browser.sleep(2000);
        await waitForElement(By.xpath(`//p[contains(text(), '${TEST_MESSAGE}')]`));
    }

    async function checkMessage() {
        await browser.get(`https://${app.fqdn}/${TEST_TEAM}/channels/${DEFAULT_CHANNEL}`);
        await browser.sleep(4000);
        await browser.navigate().refresh(); // not sure why, but for ci . browser.executeScript('location.reload()')
        await waitForElement(By.xpath(`//p[contains(text(), '${TEST_MESSAGE}')]`));
    }

    async function setLandingpageSeen() {
        await browser.get(`https://${app.fqdn}` + '/landing');

        await browser.sleep(1000);
        await browser.executeScript('localStorage[\'__landingPageSeen__\'] = true');
    }

    async function completeSignup() {
        await browser.get(`https://${app.fqdn}/signup_user_complete`);
        await waitForElement(By.xpath('//input[@name="email"]'));
        await browser.findElement(By.xpath('//input[@name="email"]')).sendKeys(email);
        await browser.findElement(By.xpath('//input[@name="name"]')).sendKeys(username);
        await browser.findElement(By.xpath('//input[@type="password"]')).sendKeys(password);
        await browser.sleep(2000);
        await browser.findElement(By.xpath('//button[@type="submit"]')).click();

        // select org
        await waitForElement(By.xpath('//input[@placeholder="Organization name"]'));
        await browser.findElement(By.xpath('//input[@placeholder="Organization name"]')).sendKeys(TEST_TEAM);
        await browser.sleep(1000);
        await browser.findElement(By.xpath('//button[@data-testid="continue"]')).click();
        await browser.sleep(1000);

        await waitForElement(By.xpath('//button[span[text()="Finish setup"]]'));
        await browser.findElement(By.xpath('//button[span[text()="Finish setup"]]')).click();

        await waitForPath(`/${TEST_TEAM}/channels/${DEFAULT_CHANNEL}`);
    }

    async function checkEmailSetting() {
        await browser.get(`https://${app.fqdn}/admin_console/environment/smtp`);
        await browser.sleep(4000);
        await browser.navigate().refresh(); // not sure why, but for ci . browser.executeScript('location.reload()')
        await waitForElement(By.xpath('//button/span[text()="Test Connection"]'));

        const button = await browser.findElement(By.xpath('//button/span[text()="Test Connection"]'));
        await browser.executeScript('arguments[0].scrollIntoView(true)', button);

        await button.click();

        await waitForElement(By.xpath('//span[contains(text(), "No errors were reported while sending an email")]'));
    }

    async function dismissWelcomeBubble() {
        await browser.get(`https://${app.fqdn}`);
        await waitForElement(By.xpath('//span[text()="Welcome to Mattermost"]'));
        await waitForElement(By.xpath('//span[contains(text(), "No thanks, I")]'));
        await browser.findElement(By.xpath('//span[contains(text(), "No thanks, I")]')).click();
        await browser.sleep(2000);
    }

    xit('build app', function () { execSync('cloudron build', EXEC_ARGS); });
    it('install app', function () { execSync('cloudron install --location ' + LOCATION, EXEC_ARGS); });

    it('can get app information', getAppInfo);
    it('set landingpage seen', setLandingpageSeen);
    it('can complete sign up', completeSignup);
    it('can dismiss welcome bubble', dismissWelcomeBubble);
    it('can close tutorial tip', closeTutorialTip);
    it('can send message', sendMessage);
    it('can send email', checkEmailSetting);

    it('clear cache', clearCache);
    it('backup app', function () { execSync('cloudron backup create --app ' + app.id, EXEC_ARGS); });
    it('restore app', async function () {
        await browser.get('about:blank'); // ensure we don't hit NXDOMAIN in the mean time
        const backups = JSON.parse(execSync('cloudron backup list --raw --app ' + app.id));
        execSync('cloudron uninstall --app ' + app.id, EXEC_ARGS);
        execSync('cloudron install --location ' + LOCATION, EXEC_ARGS);
        getAppInfo();
        execSync(`cloudron restore --backup ${backups[0].id} --app ${app.id}`, EXEC_ARGS);

        // needs some time for no apparent reason
        await browser.sleep(5000);
    });

    it('set landingpage seen', setLandingpageSeen);
    it('can login', login);
    it('message is still there', checkMessage);
    it('can send email', checkEmailSetting);

    it('can restart app', function () { execSync('cloudron restart --app ' + app.id); });

    it('message is still there', checkMessage);
    it('can send email', checkEmailSetting);

    it('move to different location', async function () {
        await browser.executeScript('localStorage.clear();');
        await browser.get('about:blank'); // ensure we don't hit NXDOMAIN in the mean time
        execSync('cloudron configure --location ' + LOCATION + '2 --app ' + app.id, EXEC_ARGS);
    });

    it('can get app information', getAppInfo);
    it('set landingpage seen', setLandingpageSeen);
    it('can login', login);
    it('message is still there', checkMessage);
    it('can send email', checkEmailSetting);

    it('uninstall app', async function () {
        await browser.get('about:blank'); // ensure we don't hit NXDOMAIN in the mean time
        execSync('cloudron uninstall --app ' + app.id, EXEC_ARGS);
    });

    // test update
    it('can install app', function () { execSync(`cloudron install --appstore-id ${appManifest.id} --location ${LOCATION}`, EXEC_ARGS); });

    it('can get app information', getAppInfo);
    it('set landingpage seen', setLandingpageSeen);
    it('can complete sign up', completeSignup);
    it('can dismiss welcome bubble', dismissWelcomeBubble);
    it('can send message', sendMessage);

    it('clear cache', clearCache);

    it('can update', function () { execSync('cloudron update --app ' + app.id, EXEC_ARGS); });

    it('can get app information', getAppInfo);
    it('set landingpage seen', setLandingpageSeen);
    it('can login', login);
    it('message is still there', checkMessage);
    it('can send email', checkEmailSetting);

    it('uninstall app', async function () {
        await browser.get('about:blank'); // ensure we don't hit NXDOMAIN in the mean time
        execSync('cloudron uninstall --app ' + app.id, EXEC_ARGS);
    });
});
