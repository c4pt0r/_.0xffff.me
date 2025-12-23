#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { marked } = require('marked');

const pagesDir = path.join(__dirname, '../pages');
const files = fs.readdirSync(pagesDir);

files.forEach(file => {
  if (file.endsWith('.md')) {
    const mdPath = path.join(pagesDir, file);
    const htmlPath = path.join(pagesDir, file.replace('.md', '.html'));

    const markdown = fs.readFileSync(mdPath, 'utf8');
    const html = `<!DOCTYPE html>
<html>
${marked(markdown)}
</html>`;

    fs.writeFileSync(htmlPath, html);
    console.log(`Converted ${file} to ${file.replace('.md', '.html')}`);
  }
});
