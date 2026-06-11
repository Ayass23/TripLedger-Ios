import os

def replace_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Replacements for foreground color
    content = content.replace('.foregroundColor(.white)', '.foregroundColor(.textPrimary)')
    content = content.replace('.foregroundColor(.white.opacity', '.foregroundColor(.textPrimary.opacity')
    
    # Replacements for backgrounds, borders, fills
    content = content.replace('Color.white.opacity', 'Color.textPrimary.opacity')
    
    # Text colors
    content = content.replace('foregroundColor(.white)', 'foregroundColor(.textPrimary)')

    with open(filepath, 'w') as f:
        f.write(content)

for root, dirs, files in os.walk('./TripLedger'):
    for file in files:
        if file.endswith('.swift') and 'AppTheme.swift' not in file:
            replace_in_file(os.path.join(root, file))

print("Done replacing colors.")
