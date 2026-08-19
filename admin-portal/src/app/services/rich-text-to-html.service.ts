import { Injectable } from '@angular/core';

/**
 * What a conversion produced, so the UI can tell the user what actually happened
 * rather than silently swapping their content for something else.
 */
export interface ConversionResult {
  html: string;
  /** Counts of each element produced, e.g. "3 headings, 12 paragraphs". */
  summary: string;
  /** Things the author needs to know — most importantly, dropped images. */
  warnings: string[];
  source: 'word' | 'html' | 'text';
}

/** Inline styles applied to each element. */
interface StyleMap {
  [tag: string]: string;
}

/**
 * Converts pasted Word / Google Docs content, or plain text, into clean semantic
 * HTML with inline styles.
 *
 * <p><strong>Why inline styles.</strong> This HTML is rendered inside the student
 * mobile app, which has no access to the admin portal's stylesheet. A class name
 * would carry no formatting there, so every rule has to travel with the element.
 *
 * <p><strong>Why Word needs special handling.</strong> Word does not emit real lists.
 * A bulleted list arrives as a run of ordinary paragraphs, each tagged with an
 * {@code mso-list} style and carrying the bullet glyph (·, o, §) in its own span.
 * Naively stripping tags would leave a wall of paragraphs beginning with stray
 * symbols, so {@link #rebuildWordLists} reconstructs genuine {@code <ul>}/{@code <ol>}
 * structure from that metadata.
 *
 * <p><strong>This also sanitises.</strong> The output is rendered to students, so
 * scripts, event handlers and {@code javascript:} URLs are removed. A faculty member
 * pasting from a compromised document should not be able to inject anything into the
 * app, and they have no way to audit the markup themselves.
 */
@Injectable({ providedIn: 'root' })
export class RichTextToHtmlService {

  /**
   * Inline styles per element, tuned for reading on a phone: generous line height,
   * clear heading hierarchy, comfortable list indentation.
   */
  private readonly styles: StyleMap = {
    h1: 'font-size:22px;font-weight:700;margin:20px 0 10px;line-height:1.3;color:#0F172A;',
    h2: 'font-size:19px;font-weight:700;margin:18px 0 9px;line-height:1.3;color:#0F172A;',
    h3: 'font-size:17px;font-weight:600;margin:16px 0 8px;line-height:1.35;color:#1E293B;',
    h4: 'font-size:15px;font-weight:600;margin:14px 0 7px;line-height:1.4;color:#1E293B;',
    h5: 'font-size:14px;font-weight:600;margin:12px 0 6px;color:#334155;',
    h6: 'font-size:13px;font-weight:600;margin:12px 0 6px;color:#334155;',
    p: 'font-size:15px;line-height:1.7;margin:0 0 12px;color:#1E293B;',
    ul: 'margin:0 0 14px;padding-left:22px;',
    ol: 'margin:0 0 14px;padding-left:22px;',
    li: 'font-size:15px;line-height:1.7;margin-bottom:6px;color:#1E293B;',
    blockquote: 'margin:0 0 14px;padding:10px 16px;border-left:4px solid #EAB308;background:#FFFBEB;'
      + 'font-size:15px;line-height:1.7;color:#78350F;',
    table: 'width:100%;border-collapse:collapse;margin:0 0 16px;font-size:14px;',
    th: 'border:1px solid #E2E8F0;padding:8px 10px;text-align:left;background:#F8FAFC;font-weight:600;',
    td: 'border:1px solid #E2E8F0;padding:8px 10px;',
    a: 'color:#2563EB;text-decoration:underline;',
    code: 'font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px;background:#F1F5F9;'
      + 'padding:2px 5px;border-radius:4px;',
    pre: 'font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px;background:#0F172A;'
      + 'color:#E2E8F0;padding:14px;border-radius:8px;overflow-x:auto;margin:0 0 14px;line-height:1.5;',
    img: 'max-width:100%;height:auto;border-radius:8px;margin:0 0 14px;display:block;',
    hr: 'border:none;border-top:1px solid #E2E8F0;margin:20px 0;'
  };

  /** Elements kept in the output. Anything else is unwrapped or dropped. */
  private readonly allowed = new Set([
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'ul', 'ol', 'li', 'blockquote',
    'table', 'thead', 'tbody', 'tr', 'th', 'td', 'a', 'strong', 'b', 'em', 'i',
    'u', 's', 'sub', 'sup', 'code', 'pre', 'br', 'hr', 'img'
  ]);

  /**
   * Bullet glyphs Word and PowerPoint use as literal characters at the start of a
   * list paragraph. Symbol-font bullets arrive as these code points.
   */
  private readonly bulletGlyphs = /^[\s ]*([•·▪◦‣∙o§–—*-]|[])[\s ]+/;

  /** "1." / "1)" / "a." / "iv)" style markers. */
  private readonly orderedMarker = /^[\s ]*(\d{1,3}|[a-zA-Z]|[ivxIVX]{1,5})[.)][\s ]+/;

  /**
   * Converts whatever the author supplied, choosing the right strategy.
   *
   * @param input either HTML (from a rich paste) or plain text
   */
  convert(input: string): ConversionResult {
    const trimmed = (input || '').trim();
    if (!trimmed) {
      return { html: '', summary: 'Nothing to convert.', warnings: [], source: 'text' };
    }
    return this.looksLikeHtml(trimmed)
      ? this.fromHtml(trimmed)
      : this.fromPlainText(trimmed);
  }

  /**
   * True when the input already contains markup worth parsing.
   *
   * <p>Requires a recognisable block or formatting tag rather than any angle bracket,
   * so lesson notes that merely mention "x < y" are still treated as plain text.
   */
  looksLikeHtml(input: string): boolean {
    return /<(\/?)(p|div|h[1-6]|ul|ol|li|table|span|br|strong|b|em|i|a|img|blockquote|pre)\b/i.test(input);
  }

  /** True when the markup carries Word's fingerprints. */
  isWordHtml(input: string): boolean {
    return /mso-|urn:schemas-microsoft-com|class=(["']?)Mso|<o:p/i.test(input);
  }

  // ===================================================================
  // HTML path — a rich paste from Word, Google Docs or a web page
  // ===================================================================

  fromHtml(html: string): ConversionResult {
    const warnings: string[] = [];
    const wasWord = this.isWordHtml(html);

    // Strip conditional comments and Word's XML islands before parsing; left in
    // place they confuse the parser and can smuggle content past the element filter.
    //
    // The downlevel-revealed form <![if !supportLists]> ... <![endif]> matters
    // specifically: it is NOT a standard comment, so it survives comment stripping and
    // sits in front of the bullet marker, which previously defeated marker removal and
    // left a literal "·" at the front of every list item.
    let cleaned = html
      .replace(/<!\[if[^\]]*\]>/gi, '')
      .replace(/<!\[endif\]>/gi, '')
      .replace(/<!--[\s\S]*?-->/g, '')
      .replace(/<\?xml[\s\S]*?\?>/gi, '')
      .replace(/<(script|style|meta|link|title)\b[\s\S]*?<\/\1>/gi, '')
      .replace(/<(script|style|meta|link)\b[^>]*\/?>/gi, '')
      .replace(/<\/?o:[^>]*>/gi, '')
      .replace(/<\/?w:[^>]*>/gi, '');

    const doc = new DOMParser().parseFromString(cleaned, 'text/html');
    const body = doc.body;

    if (wasWord) {
      this.rebuildWordLists(doc, body);
    }

    const out: string[] = [];
    const counts: Record<string, number> = {};

    body.childNodes.forEach(node => {
      const rendered = this.renderNode(node, counts, warnings, doc);
      if (rendered.trim()) {
        out.push(rendered);
      }
    });

    let result = out.join('\n').trim();
    // Tidy the artefacts Word leaves behind: empty paragraphs from spacing runs,
    // and non-breaking spaces used for indentation.
    result = result
      .replace(/<p[^>]*>(\s|&nbsp;|<br\s*\/?>)*<\/p>/gi, '')
      .replace(/ /g, ' ')
      .replace(/\n{3,}/g, '\n\n');

    return {
      html: result,
      summary: this.describe(counts),
      warnings,
      source: wasWord ? 'word' : 'html'
    };
  }

  /**
   * Reconstructs real lists from Word's flat paragraphs.
   *
   * <p>Word marks a list item as a paragraph carrying {@code mso-list:l0 level1 lfo1}
   * (or class {@code MsoListParagraph}), with the visible bullet or number in a
   * leading span. This groups consecutive such paragraphs, works out the nesting
   * depth from {@code levelN}, decides ordered versus unordered from the marker text,
   * and replaces the run with proper {@code <ul>}/{@code <ol>} elements.
   */
  private rebuildWordLists(doc: Document, body: HTMLElement): void {
    const paragraphs = Array.from(body.querySelectorAll('p'));
    let index = 0;

    while (index < paragraphs.length) {
      const para = paragraphs[index];
      if (!this.isWordListParagraph(para)) {
        index++;
        continue;
      }

      // Collect the consecutive run of list paragraphs starting here.
      const run: HTMLElement[] = [];
      let cursor: Element | null = para;
      while (cursor && cursor.tagName === 'P' && this.isWordListParagraph(cursor as HTMLElement)) {
        run.push(cursor as HTMLElement);
        cursor = cursor.nextElementSibling;
      }

      const ordered = this.isOrderedItem(run[0]);
      const list = doc.createElement(ordered ? 'ol' : 'ul');

      // Stack of open lists by nesting depth, so level2 items nest inside level1.
      const stack: { level: number; el: HTMLElement }[] = [{ level: 1, el: list }];

      for (const item of run) {
        const level = this.wordListLevel(item);
        const li = doc.createElement('li');
        li.innerHTML = this.stripListMarker(item);

        while (stack.length > 1 && stack[stack.length - 1].level > level) {
          stack.pop();
        }
        if (level > stack[stack.length - 1].level) {
          // Nest a new list inside the previous item at the shallower level.
          const nested = doc.createElement(this.isOrderedItem(item) ? 'ol' : 'ul');
          const parentList = stack[stack.length - 1].el;
          const lastItem = parentList.lastElementChild;
          (lastItem ?? parentList).appendChild(nested);
          stack.push({ level, el: nested });
        }
        stack[stack.length - 1].el.appendChild(li);
      }

      run[0].parentNode?.insertBefore(list, run[0]);
      run.forEach(p => p.remove());
      index += run.length;
    }
  }

  private isWordListParagraph(el: HTMLElement): boolean {
    const style = el.getAttribute('style') || '';
    const cls = el.getAttribute('class') || '';
    if (/mso-list\s*:/i.test(style) || /MsoListParagraph/i.test(cls)) {
      return true;
    }
    // Some Word versions omit mso-list and leave only the glyph.
    return this.bulletGlyphs.test(this.textOf(el));
  }

  private wordListLevel(el: HTMLElement): number {
    const style = el.getAttribute('style') || '';
    const match = /mso-list:[^;]*level(\d+)/i.exec(style);
    if (match) {
      return parseInt(match[1], 10);
    }
    // Fall back to indentation: Word uses roughly half an inch per level.
    const indent = /margin-left:\s*([\d.]+)(pt|in)/i.exec(style);
    if (indent) {
      const value = parseFloat(indent[1]);
      const inches = indent[2].toLowerCase() === 'in' ? value : value / 72;
      return Math.max(1, Math.round(inches / 0.5));
    }
    return 1;
  }

  private isOrderedItem(el: HTMLElement): boolean {
    const text = this.textOf(el);
    return this.orderedMarker.test(text) && !this.bulletGlyphs.test(text);
  }

  /**
   * Removes the visible bullet or number, which the real list now renders itself.
   *
   * <p>Done against the DOM rather than with a regex over {@code innerHTML}. Word nests
   * the glyph inside a span that itself contains a spacer span, so a non-greedy regex
   * closes on the wrong tag, and the marker is preceded by conditional-comment
   * remnants that defeat any start-anchored pattern. Removing the elements Word
   * explicitly flags with {@code mso-list:Ignore} is both simpler and exact.
   */
  private stripListMarker(item: HTMLElement): string {
    const clone = item.cloneNode(true) as HTMLElement;

    // Word's own signal that a span is decoration, not content.
    clone.querySelectorAll('[style*="mso-list"]').forEach(el => {
      if (/mso-list:\s*Ignore/i.test(el.getAttribute('style') || '')) {
        el.remove();
      }
    });

    // Some builds omit mso-list and rely only on a symbol font for the glyph.
    clone.querySelectorAll('span').forEach(span => {
      const style = span.getAttribute('style') || '';
      if (!/font-family:\s*["']?(Symbol|Wingdings)/i.test(style)) {
        return;
      }
      // Only remove it when it holds nothing but a marker, so a span that happens to
      // use a symbol font mid-sentence is left alone.
      const text = (span.textContent || '').replace(/[\s ]/g, '');
      if (text.length <= 2) {
        span.remove();
      }
    });

    return clone.innerHTML
      // Whatever glyph or number remains as plain text at the start.
      .replace(/^(\s|&nbsp;| )+/i, '')
      .replace(this.bulletGlyphs, '')
      .replace(this.orderedMarker, '')
      .replace(/^(\s|&nbsp;| )+/i, '')
      .trim();
  }

  /**
   * Rebuilds one node as clean HTML.
   *
   * <p>Unknown elements are unwrapped rather than dropped, so their text survives —
   * losing a faculty member's content because Word emitted an unexpected wrapper
   * would be far worse than losing its formatting.
   */
  private renderNode(node: Node, counts: Record<string, number>,
                     warnings: string[], doc: Document): string {
    if (node.nodeType === Node.TEXT_NODE) {
      return this.escape(node.textContent || '');
    }
    if (node.nodeType !== Node.ELEMENT_NODE) {
      return '';
    }

    const el = node as HTMLElement;
    let tag = el.tagName.toLowerCase();

    // A Word heading arrives as a styled paragraph, not an <h> tag.
    if (tag === 'p') {
      const heading = this.wordHeadingLevel(el);
      if (heading) {
        tag = `h${heading}`;
      }
    }

    // Divs and spans carry no meaning here — keep the children, drop the wrapper.
    if (tag === 'div' || tag === 'span' || tag === 'font' || !this.allowed.has(tag)) {
      if (tag === 'img') {
        return '';
      }
      const inner = this.renderChildren(el, counts, warnings, doc);
      // A bare div that behaves like a block becomes a paragraph so spacing survives.
      if (tag === 'div' && inner.trim() && !/^<(h[1-6]|p|ul|ol|table|blockquote|pre)/i.test(inner.trim())) {
        counts['p'] = (counts['p'] || 0) + 1;
        return `<p style="${this.styles['p']}">${inner.trim()}</p>`;
      }
      return inner;
    }

    if (tag === 'br') {
      return '<br>';
    }
    if (tag === 'hr') {
      return `<hr style="${this.styles['hr']}">`;
    }

    if (tag === 'img') {
      const src = el.getAttribute('src') || '';
      // Word references pasted images as local file:// paths, which are meaningless
      // once the note reaches a student's phone. Dropping them silently would be
      // worse than saying so.
      if (!/^(https?:)?\/\//i.test(src) && !/^data:image\//i.test(src)) {
        if (!warnings.some(w => w.startsWith('Images'))) {
          warnings.push('Images could not be carried over — Word links them to files on your '
            + 'computer. Upload them somewhere and add them with an image URL.');
        }
        return '';
      }
      counts['image'] = (counts['image'] || 0) + 1;
      const alt = this.escape(el.getAttribute('alt') || '');
      return `<img src="${this.escapeAttr(src)}" alt="${alt}" style="${this.styles['img']}">`;
    }

    // Google Docs wraps everything in <b style="font-weight:normal">, which would
    // otherwise bold the entire document.
    if ((tag === 'b' || tag === 'strong') && /font-weight:\s*normal/i.test(el.getAttribute('style') || '')) {
      return this.renderChildren(el, counts, warnings, doc);
    }

    const inner = this.renderChildren(el, counts, warnings, doc);

    // Drop elements that ended up empty, except those that are meaningful when bare.
    if (!inner.trim() && !['td', 'th', 'br', 'hr'].includes(tag)) {
      return '';
    }

    if (/^h[1-6]$/.test(tag) || ['p', 'li', 'blockquote', 'pre'].includes(tag)) {
      counts[/^h[1-6]$/.test(tag) ? 'heading' : tag] =
        (counts[/^h[1-6]$/.test(tag) ? 'heading' : tag] || 0) + 1;
    }
    if (tag === 'ul' || tag === 'ol') {
      counts['list'] = (counts['list'] || 0) + 1;
    }
    if (tag === 'table') {
      counts['table'] = (counts['table'] || 0) + 1;
    }

    if (tag === 'a') {
      const href = el.getAttribute('href') || '';
      // Only http(s) and mailto survive; javascript: and data: URLs are how a pasted
      // document would attack the student app.
      if (!/^(https?:|mailto:)/i.test(href)) {
        return inner;
      }
      return `<a href="${this.escapeAttr(href)}" style="${this.styles['a']}" `
        + `target="_blank" rel="noopener noreferrer">${inner}</a>`;
    }

    const style = this.styles[tag];
    return style ? `<${tag} style="${style}">${inner}</${tag}>` : `<${tag}>${inner}</${tag}>`;
  }

  private renderChildren(el: HTMLElement, counts: Record<string, number>,
                         warnings: string[], doc: Document): string {
    let out = '';
    el.childNodes.forEach(child => {
      out += this.renderNode(child, counts, warnings, doc);
    });
    return out;
  }

  /** Detects a Word heading, which is a paragraph styled rather than an h tag. */
  private wordHeadingLevel(el: HTMLElement): number | null {
    const cls = el.getAttribute('class') || '';
    const style = el.getAttribute('style') || '';

    if (/MsoTitle/i.test(cls)) {
      return 1;
    }
    const byClass = /MsoHeading\s*(\d)/i.exec(cls);
    if (byClass) {
      return Math.min(6, parseInt(byClass[1], 10));
    }
    const byOutline = /mso-outline-level:\s*(\d)/i.exec(style);
    if (byOutline) {
      return Math.min(6, parseInt(byOutline[1], 10));
    }
    // A short, fully bold paragraph is almost always a heading in practice.
    const text = this.textOf(el).trim();
    if (text && text.length <= 80 && !/[.!?]$/.test(text) && this.isEntirelyBold(el)) {
      return 3;
    }
    return null;
  }

  private isEntirelyBold(el: HTMLElement): boolean {
    const text = this.textOf(el).trim();
    if (!text) {
      return false;
    }
    const bold = Array.from(el.querySelectorAll('b,strong'))
      .map(b => (b.textContent || '').trim())
      .join(' ')
      .trim();
    if (bold && bold.length >= text.length - 2) {
      return true;
    }
    return /font-weight:\s*(bold|[6-9]00)/i.test(el.getAttribute('style') || '');
  }

  private textOf(el: Element): string {
    return el.textContent || '';
  }

  // ===================================================================
  // Plain-text path — typed notes, or a paste that lost its formatting
  // ===================================================================

  /**
   * Infers structure from plain text.
   *
   * <p>Used when the clipboard carried no HTML — the author typed the notes, pasted
   * from Notepad, or their browser gave us text only. The rules mirror how people
   * actually write notes: a line ending in a colon introduces something, a short line
   * with no full stop is a heading, lines starting with a dash are bullets.
   */
  fromPlainText(text: string): ConversionResult {
    const lines = text.replace(/\r\n?/g, '\n').split('\n');
    const out: string[] = [];
    const counts: Record<string, number> = {};

    let paragraph: string[] = [];
    let listItems: string[] = [];
    let listOrdered = false;

    const flushParagraph = () => {
      if (!paragraph.length) {
        return;
      }
      counts['p'] = (counts['p'] || 0) + 1;
      out.push(`<p style="${this.styles['p']}">${this.inline(paragraph.join(' '))}</p>`);
      paragraph = [];
    };

    const flushList = () => {
      if (!listItems.length) {
        return;
      }
      const tag = listOrdered ? 'ol' : 'ul';
      counts['list'] = (counts['list'] || 0) + 1;
      const items = listItems
        .map(i => `<li style="${this.styles['li']}">${this.inline(i)}</li>`)
        .join('');
      out.push(`<${tag} style="${this.styles[tag]}">${items}</${tag}>`);
      listItems = [];
    };

    const flushAll = () => { flushParagraph(); flushList(); };

    for (let i = 0; i < lines.length; i++) {
      const raw = lines[i];
      const line = raw.trim();

      if (!line) {
        flushAll();
        continue;
      }

      // Markdown-style headings, since people often type these out of habit.
      const md = /^(#{1,6})\s+(.*)$/.exec(line);
      if (md) {
        flushAll();
        const level = md[1].length;
        counts['heading'] = (counts['heading'] || 0) + 1;
        out.push(`<h${level} style="${this.styles['h' + level]}">${this.inline(md[2])}</h${level}>`);
        continue;
      }

      // A rule of dashes or equals signs.
      if (/^([-=_*]\s*){3,}$/.test(line)) {
        flushAll();
        out.push(`<hr style="${this.styles['hr']}">`);
        continue;
      }

      if (this.bulletGlyphs.test(line)) {
        flushParagraph();
        if (listOrdered && listItems.length) {
          flushList();
        }
        listOrdered = false;
        listItems.push(line.replace(this.bulletGlyphs, ''));
        continue;
      }

      if (this.orderedMarker.test(line)) {
        flushParagraph();
        if (!listOrdered && listItems.length) {
          flushList();
        }
        listOrdered = true;
        listItems.push(line.replace(this.orderedMarker, ''));
        continue;
      }

      // Not a list item, so any open list ends here.
      flushList();

      if (this.looksLikeHeading(line, lines[i + 1])) {
        flushParagraph();
        const level = this.headingLevelFor(line);
        counts['heading'] = (counts['heading'] || 0) + 1;
        out.push(`<h${level} style="${this.styles['h' + level]}">`
          + `${this.inline(line.replace(/:$/, ''))}</h${level}>`);
        continue;
      }

      paragraph.push(line);
    }
    flushAll();

    return {
      html: out.join('\n'),
      summary: this.describe(counts),
      warnings: [],
      source: 'text'
    };
  }

  /**
   * Whether a line reads as a heading.
   *
   * <p>Deliberately conservative. Wrongly promoting a sentence to a heading is more
   * jarring than leaving a heading as a paragraph, so a line only qualifies when it is
   * short, lacks terminal punctuation, and either shouts, ends in a colon, or is
   * followed by a blank line.
   */
  private looksLikeHeading(line: string, next: string | undefined): boolean {
    if (line.length > 90 || /[.!?,;]$/.test(line)) {
      return false;
    }
    if (line.endsWith(':') && line.length <= 80) {
      return true;
    }
    const letters = line.replace(/[^A-Za-z]/g, '');
    const isShouted = letters.length >= 3 && letters === letters.toUpperCase();
    if (isShouted && line.length <= 80) {
      return true;
    }
    // "Chapter 2", "Unit 3 - Arrays", "1.2 Loops"
    if (/^(chapter|unit|module|section|topic|part|lesson)\b/i.test(line) && line.length <= 80) {
      return true;
    }
    // A short line followed by a blank line, where the next content starts a block.
    return line.length <= 60 && (next === undefined || next.trim() === '');
  }

  private headingLevelFor(line: string): number {
    const letters = line.replace(/[^A-Za-z]/g, '');
    if (letters.length >= 3 && letters === letters.toUpperCase()) {
      return 2;
    }
    if (/^(chapter|unit|module|part)\b/i.test(line)) {
      return 2;
    }
    return 3;
  }

  /**
   * Applies inline emphasis, escaping first so the author's text cannot inject markup.
   */
  private inline(text: string): string {
    let out = this.escape(text);
    out = out.replace(/`([^`]+)`/g, `<code style="${this.styles['code']}">$1</code>`);
    out = out.replace(/(\*\*|__)(?=\S)([\s\S]*?\S)\1/g, '<strong>$2</strong>');
    out = out.replace(/(^|[\s(])[*_](?=\S)([^*_]*?\S)[*_](?=[\s).,!?]|$)/g, '$1<em>$2</em>');
    // Bare URLs become links, which is what the author meant by typing one.
    out = out.replace(/(^|\s)(https?:\/\/[^\s<]+)/g,
      `$1<a href="$2" style="${this.styles['a']}" target="_blank" rel="noopener noreferrer">$2</a>`);
    return out;
  }

  // ===================================================================
  // Helpers
  // ===================================================================

  private describe(counts: Record<string, number>): string {
    const parts: string[] = [];
    const label = (n: number, singular: string) => `${n} ${singular}${n === 1 ? '' : 's'}`;
    if (counts['heading']) parts.push(label(counts['heading'], 'heading'));
    if (counts['p']) parts.push(label(counts['p'], 'paragraph'));
    if (counts['list']) parts.push(label(counts['list'], 'list'));
    if (counts['table']) parts.push(label(counts['table'], 'table'));
    if (counts['image']) parts.push(label(counts['image'], 'image'));
    if (counts['blockquote']) parts.push(label(counts['blockquote'], 'quote'));
    return parts.length ? `Converted ${parts.join(', ')}.` : 'Nothing recognisable to convert.';
  }

  private escape(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  private escapeAttr(value: string): string {
    return this.escape(value).replace(/"/g, '&quot;');
  }
}
