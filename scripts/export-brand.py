"""Export the approved September logo. Requires cairosvg, pillow, fonttools.
Run from the app directory. Geometry is shared with the generated Flutter painter.
"""
from pathlib import Path
from io import BytesIO
import json
import cairosvg
from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parents[1]
B = ROOT / 'assets/brand'
GREEN, CORAL, CREAM = '#145247', '#F56853', '#F7EBD3'
# Hand-drawn vector reconstruction of the supplied artwork, in reference coordinates.
paths = [
    (CORAL, 'M408 492 C425 394 457 340 532 314 C546 309 555 311 563 320 C598 357 655 357 690 320 C698 311 707 309 721 314 C796 340 829 394 846 492 C809 417 714 381 627 381 C540 381 445 417 408 492 Z'),
    (CREAM, 'M444 478 C539 391 714 391 809 478 C720 497 669 571 627 688 C585 571 533 497 444 478 Z'),
    (GREEN, 'M302 488 C308 463 323 473 340 485 C386 516 434 524 480 544 C533 568 553 642 614 795 C620 811 601 812 580 806 C419 771 297 623 300 510 C300 501 301 494 302 488 Z'),
    (GREEN, 'M952 488 C946 463 931 473 914 485 C868 516 820 524 774 544 C721 568 701 642 640 795 C634 811 653 812 674 806 C835 771 957 623 954 510 C954 501 953 494 952 488 Z'),
]
circles = [(CORAL,627,261,69),(GREEN,351,403,64),(GREEN,903,403,64)]
def body(small=False, mono=False):
    def color(c): return '#145247' if mono else c
    return ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color(c)}"/>' for c,x,y,r in circles) + ''.join(f'<path d="{d}" fill="{color(c)}"/>' for c,d in paths if not ((small or mono) and c == CREAM))
def svg(content, view='240 135 774 774'):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}">{content}</svg>'
def save(name, content): (B/name).write_text(content)
mark=svg(body()); small=svg(body(True)); mono=svg(body(True,True))
save('vriendtime-mark.svg',mark); save('vriendtime-mark-small.svg',small); save('vriendtime-mark-mono.svg',mono)
icon=svg('<rect width="1024" height="1024" fill="#FFFAF4"/><g transform="translate(512 512) scale(.98) translate(-627 -522)">'+body(True)+'</g>','0 0 1024 1024')
save('vriendtime-app-icon.svg',icon)
# Outline the bundled wordmark font, so exported SVGs need no installed fonts.
font=instantiateVariableFont(TTFont(ROOT/'assets/fonts/Manrope-Variable.ttf'),{'wght':800})
glyphs=font.getGlyphSet(); cmap=font.getBestCmap(); units=font['head'].unitsPerEm
x=0; letters=[]
for i,ch in enumerate('VriendTime'):
    name=cmap[ord(ch)]; pen=SVGPathPen(glyphs); glyphs[name].draw(pen)
    letters.append(f'<path transform="translate({x} 0)" d="{pen.getCommands()}" fill="{GREEN if i<6 else CORAL}"/>')
    x+=font['hmtx'][name][0]
scale=1020/x
word=f'<g transform="translate(117 1010) scale({scale} {-scale})">'+''.join(letters)+'</g>'
lockup=svg(body()+word,'70 150 1114 910'); save('vriendtime-logo.svg',lockup)
def render(source,w,h=None):
    return Image.open(BytesIO(cairosvg.svg2png(bytestring=source.encode(),output_width=w,output_height=h or w))).convert('RGBA')
def output(path,img):
    path.parent.mkdir(parents=True,exist_ok=True)
    if img.mode == 'RGBA' and img.getextrema()[3] == (255,255): img = img.convert('RGB')
    img.save(path)
output(B/'vriendtime-icon.png',render(mark,1024))
output(B/'vriendtime-logo.png',render(lockup,1224,1000))
output(B/'vriendtime-logo-ui.webp',render(lockup,612,500))
for folder in ['web','web/icons','android/app/src/main/res','ios/Runner/Assets.xcassets','macos/Runner/Assets.xcassets']:
    for path in (ROOT/folder).rglob('*.png'):
        if not any(k in str(path) for k in ['Icon','icon','favicon','LaunchImage']): continue
        with Image.open(path) as old: w,h=old.size
        source=small if 'favicon' in path.name else icon
        if 'LaunchImage' in path.name: source=mark
        output(path,render(source,w,h))
output(ROOT/'windows/runner/resources/app_icon.ico',render(icon,256))
# Compact review sheet, including small-size variants.
preview=svg('<rect width="1400" height="900" fill="#FFFAF4"/><g transform="translate(20 20) scale(.75)">'+body()+word+'</g><g transform="translate(1040 160) scale(.32) translate(-627 -522)">'+body()+'</g><g transform="translate(1040 460) scale(.16) translate(-627 -522)">'+body(True)+'</g><g transform="translate(1000 680) scale(.0413) translate(-627 -522)">'+body(True)+'</g><g transform="translate(1090 680) scale(.0207) translate(-627 -522)">'+body(True)+'</g>','0 0 1400 900')
save('vriendtime-brand-sheet.svg',preview); output(B/'vriendtime-brand-sheet.png',render(preview,1400,900))
# Generate the painter from exactly the same paths, using SVG command subset M/C/Z.
import re
def dart_path(d):
    tokens=re.findall(r'[MCZ]|-?\d+(?:\.\d+)?',d); out='Path()'; i=0
    while i<len(tokens):
        c=tokens[i]; i+=1
        n={'M':2,'C':6,'Z':0}[c]; vals=tokens[i:i+n]; i+=n
        out+='..'+{'M':'moveTo','C':'cubicTo','Z':'close'}[c]+'('+','.join(vals)+')'
    return out
code='''import 'package:flutter/material.dart';

/// Approved three-person mark. Generated by scripts/export-brand.py.
class VriendTimeMarkPainter extends CustomPainter {
  const VriendTimeMarkPainter({this.small = false, this.top = 0, this.left = 0, this.right = 0, this.centerOpacity = 1});
  final bool small;
  final double top, left, right, centerOpacity;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 774, size.height / 774);
    canvas.translate(-240, -135);
'''
for index, path_index in [(0,0),(1,2),(2,3)]:
    offset = ['0, -top', '-left, 0', 'right, 0'][index]
    code += f'    canvas.save(); canvas.translate({offset});\n'
    c,x,y,r = circles[index]
    code += f'    canvas.drawCircle(const Offset({x},{y}), {r}, Paint()..color=const Color(0xFF{c[1:]}));\n'
    c,d = paths[path_index]
    code += f'    canvas.drawPath({dart_path(d)}, Paint()..color=const Color(0xFF{c[1:]})); canvas.restore();\n'
c,d = paths[1]
code += f'    if (!small) {{ canvas.drawPath({dart_path(d)}, Paint()..color=const Color(0xFF{c[1:]}).withValues(alpha: centerOpacity)); }}\n'
code+='''    canvas.restore();
  }
  @override
  bool shouldRepaint(VriendTimeMarkPainter oldDelegate) => oldDelegate.small != small || oldDelegate.top != top || oldDelegate.left != left || oldDelegate.right != right || oldDelegate.centerOpacity != centerOpacity;
}
'''
(ROOT/'lib/src/widgets/brand_mark_painter.dart').write_text(code)
print('Exported vector, raster, platform and Flutter assets.')
