import re

with open('style.css', 'r') as f:
    content = f.read()

# 1. Fonts & Palette
palette = """/* ── Fonts ── */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&family=Space+Grotesk:wght@300;400;500;600;700&display=swap');

/* ── CSS Custom Properties ── */
:root {
  /* Core palette - Elegant Minimalist */
  --bg-void:        #000000;
  --bg-deep:        #0a0a0a;
  --bg-surface:     #111111;
  --bg-elevated:    #1c1c1c;
  --bg-card:        rgba(17, 17, 17, 0.5);

  /* Accents */
  --accent-primary: #ffffff;
  --accent-dim:     #a1a1aa;
  --accent-subtle:  #27272a;

  /* Text */
  --text-primary:   #ededed;
  --text-secondary: #a1a1aa;
  --text-muted:     #52525b;

  /* Borders */
  --border-subtle:  rgba(255, 255, 255, 0.1);
  --border-glow:    rgba(255, 255, 255, 0.15);

  /* Fonts */
  --font-display:   'Space Grotesk', sans-serif;
  --font-body:      'Inter', sans-serif;
  --font-mono:      'JetBrains Mono', monospace;

  /* Spacing */
  --space-xs:  0.25rem;
  --space-sm:  0.5rem;
  --space-md:  1rem;
  --space-lg:  1.5rem;
  --space-xl:  2rem;
  --space-2xl: 3rem;
  --space-3xl: 4rem;
  --space-4xl: 6rem;

  /* Radius */
  --radius-sm:  4px;
  --radius-md:  8px;
  --radius-lg:  12px;
  --radius-xl:  20px;

  /* Transitions */
  --ease-out:   cubic-bezier(0.16, 1, 0.3, 1);
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
}"""

content = re.sub(r'/\* ── Fonts ── \*/.*?--ease-spring:[^\n]+\n}', palette, content, flags=re.DOTALL)

# 2. Variable mapping
content = content.replace('var(--neon-purple)', 'var(--accent-primary)')
content = content.replace('var(--neon-violet)', 'var(--accent-dim)')
content = content.replace('var(--neon-cyan)', 'var(--accent-dim)')
content = content.replace('var(--neon-teal)', 'var(--accent-primary)')
content = content.replace('var(--neon-pink)', 'var(--accent-primary)')
content = content.replace('var(--neon-amber)', 'var(--accent-primary)')
content = content.replace('var(--neon-green)', 'var(--accent-primary)')
content = content.replace('var(--neon-red)', 'var(--accent-primary)')

# 3. Fix gradients
content = re.sub(r'linear-gradient\([^)]+\)', 'var(--accent-primary)', content)
content = content.replace('background: var(--accent-primary);', 'background: var(--bg-elevated);')
content = content.replace('-webkit-background-clip: text;', '')
content = content.replace('background-clip: text;', '')
content = content.replace('-webkit-text-fill-color: transparent;', '')
content = content.replace('-webkit-text-fill-color: var(--accent-primary);', 'color: var(--accent-primary);')

# 4. Remove glow orbs
content = re.sub(r'\.bg-glow-orb--\w+\s*\{[^}]+\}', '', content)
content = content.replace('.bg-glow-orb {', '.bg-glow-orb { display: none;')

with open('style.css', 'w') as f:
    f.write(content)
