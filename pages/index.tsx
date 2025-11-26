
export default function Home() {
  return (
    <div style={{ 
      maxWidth: '800px', 
      margin: '0 auto', 
      padding: '2rem',
      fontFamily: 'system-ui, -apple-system, sans-serif'
    }}>
      <h1 className="font-bold text-[26px]">Blade Deployment Template</h1>
      <p className="mt-2">
        This is a starter template showing how to set up Blade with embedded Hive database
        and multi-platform deployment automation.
      </p>
      
      <h2 className="font-bold mt-2 underline">Quick Start</h2>
      <ol>
        <li className="mt-2">Clone this repository</li>
        <li>Run: <code className="font-semibold">bun install</code></li>
        <li>Run: <code className="font-semibold">bun run dev</code></li>
        <li>Edit <code className="font-semibold">schema/index.ts</code> to add your models</li>
        <li>Run: <code className="font-semibold">blade diff --apply</code> to apply schema changes</li>
      </ol>

      <h2 className="mt-2 font-bold underline">Deployment</h2>
      <p>
        See <a className="font-bold" href="https://github.com/MaDsEm88/blade-deployment-template/blob/main/DEPLOYMENT.md">DEPLOYMENT.md</a> for deployment instructions.
      </p>

      <h3 className="mt-2 font-bold underline">Quick Deploy Check</h3>
      <pre><code className="font-semibold">bun run setup:check</code></pre>

      <h3 className="mt-2 font-bold">Deploy</h3>
      <pre><code>bun run deploy:railway  # Railway.app <br/>
bun run deploy:cloudflare   # Cloudflare Workers <br/>
flyctl deploy              # Fly.io</code></pre>

      <h2 className="mt-2 font-bold underline">Documentation</h2>
      <ul>
        <li><a className="font-semibold" href="https://github.com/MaDsEm88/blade-deployment-template/blob/main/DEPLOYMENT.md">DEPLOYMENT.md</a> - Complete deployment guide</li>
        <li><a className="font-semibold" href="https://github.com/MaDsEm88/blade-deployment-template/blob/main/DATABASE.md">DATABASE.md</a> - Database configuration</li>
      </ul>
    </div>
  );
}