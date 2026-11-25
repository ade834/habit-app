"""Import the two original photographic layers embedded in the hybrid SVG."""
from pathlib import Path
import argparse
import base64
import json
import xml.etree.ElementTree as ET

repo = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('source', nargs='?', type=Path, default=repo / 'HabitNative/docs/design/typewriter/Typewriter_Figma_Hybrid_Realistic.svg')
source = parser.parse_args().source
root = ET.parse(source).getroot()
images = list(root.iter('{http://www.w3.org/2000/svg}image'))
if len(images) != 2 or root.get('viewBox') != '0 0 2048 682':
    raise SystemExit('Expected the supplied 2048 × 682 hybrid SVG with two embedded photographic layers.')
assets = repo / 'HabitNative/HabitNative/Assets.xcassets'
for name, image in zip(['TypewriterHybridBase', 'TypewriterHybridMechanism'], images):
    uri = image.get('href') or image.get('{http://www.w3.org/1999/xlink}href')
    if not uri.startswith('data:image/png;base64,'):
        raise SystemExit('Expected an embedded PNG layer.')
    directory = assets / (name + '.imageset')
    directory.mkdir(exist_ok=True)
    (directory / (name + '.png')).write_bytes(base64.b64decode(uri.split(',', 1)[1]))
    (directory / 'Contents.json').write_text(json.dumps({'images': [{'filename': name + '.png', 'idiom': 'universal'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2))
destination = repo / 'HabitNative/docs/design/typewriter' / source.name
if source.resolve() != destination.resolve():
    destination.write_bytes(source.read_bytes())
