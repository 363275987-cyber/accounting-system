module.exports = {
  apps: [{
    name: 'accounting-app',
    cwd: '/Users/wangmengnan/.openclaw-autoclaw/workspace/accounting-app',
    script: 'npx',
    args: 'vite --host 0.0.0.0',
    watch: false,
    autorestart: true,
    max_restarts: 50,
    restart_delay: 3000,
    env: {
      PATH: '/Users/wangmengnan/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin'
    }
  }]
}
