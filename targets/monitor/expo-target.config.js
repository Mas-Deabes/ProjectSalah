/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = (config) => ({
  type: 'device-activity-monitor',
  name: 'ProjectSalahMonitor',
  bundleIdentifier: '.monitor',
  deploymentTarget: '16.4',
  entitlements: {
    'com.apple.developer.family-controls': true,
    'com.apple.security.application-groups': ['group.com.sif.projectsalah'],
  },
});