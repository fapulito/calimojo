# 📄 Template Guidelines and Best Practices

## 🔧 Issue Fixed: Nested HTML in Templates

**Problem**: Several template files contained complete HTML documents (DOCTYPE, html, head, body tags) but were being wrapped by the default layout, causing invalid nested HTML structure.

**Solution**: Added `layout => 0` to render calls for templates that contain complete HTML documents, rendering them standalone without the layout wrapper.

## 📁 Files Modified

### Perl Controller (`lib/Ships/Main.pm`)

Updated all render calls for complete HTML templates to use `layout => 0`:

```perl
# BEFORE (caused nested HTML):
$self->render(
    template => 'main',
    format   => 'html',
    handler  => 'ep',
);

# AFTER (renders standalone):
$self->render(
    template => 'main',
    format   => 'html',
    handler  => 'ep',
    layout   => 0,  # Render standalone - template contains complete HTML
);
```

### Affected Methods

1. **`default`** - Renders `main.html.ep`
2. **`terms`** - Renders `terms.html.ep`
3. **`privacy`** - Renders `privacy.html.ep`
4. **`leader`** - Renders `leader.html.ep`
5. **`deletion`** - Renders `deletion.html.ep`
6. **`book`** - Renders `main.html.ep`

## 🎯 Template Types

### 1. Complete HTML Templates (Standalone)

These templates contain full HTML documents and should use `layout => 0`:

- `main.html.ep` - Complete application interface
- `terms.html.ep` - Terms and conditions page
- `privacy.html.ep` - Privacy policy page
- `leader.html.ep` - Leaderboard rules page
- `deletion.html.ep` - Data deletion confirmation

**Characteristics**:
- Contain `<!DOCTYPE html>`
- Have `<html>`, `<head>`, and `<body>` tags
- Are self-contained HTML documents
- Should render with `layout => 0`

### 2. Fragment Templates (Layout-Wrapped)

These templates contain only page content and should use the default layout:

- Most application pages
- Partial templates
- Content that should be wrapped by layout

**Characteristics**:
- No `<!DOCTYPE html>` or `<html>` tags
- Typically start with content divs or sections
- Designed to be wrapped by `layouts/default.html.ep`
- Should render without `layout => 0` (default behavior)

## 🚀 Development Guidelines

### When to Use `layout => 0`

Use `layout => 0` when:
1. The template is a complete HTML document
2. The template contains `<!DOCTYPE html>` declaration
3. The template has `<html>`, `<head>`, and `<body>` tags
4. The template should not be wrapped by any layout

### When to Use Default Layout

Use the default layout (omit `layout => 0`) when:
1. The template contains only page content
2. The template should inherit the site's common structure
3. The template needs consistent headers, footers, navigation
4. The template is a partial or component

## 📋 Best Practices

### 1. Template Structure

**Complete HTML Template**:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Page Title</title>
    <!-- Meta tags, CSS, etc. -->
</head>
<body>
    <!-- Complete page content -->
</body>
</html>
```

**Fragment Template**:
```html
<div class="page-content">
    <!-- Page-specific content only -->
    <!-- No HTML, HEAD, or BODY tags -->
</div>
```

### 2. Rendering Code

**For Complete HTML Templates**:
```perl
$self->render(
    template => 'template_name',
    format   => 'html',
    handler  => 'ep',
    layout   => 0,  # Required for complete HTML templates
);
```

**For Fragment Templates**:
```perl
$self->render(
    template => 'template_name',
    format   => 'html',
    handler  => 'ep',
    # No layout => 0 - uses default layout
);
```

### 3. Content Organization

**Meta Tags and Titles**:
- Complete HTML templates: Include in the template's `<head>` section
- Fragment templates: Use layout's meta tags or `content_for` blocks

**CSS and JavaScript**:
- Complete HTML templates: Include directly in template
- Fragment templates: Use layout's asset pipeline or `content_for` blocks

## 🎨 Layout System

### Default Layout (`layouts/default.html.ep`)

```html
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
```

The default layout:
- Provides basic HTML structure
- Sets page title dynamically
- Wraps template content in body
- Can be extended with additional features

### Custom Layouts

For more complex applications, create additional layouts:

```html
<!-- layouts/application.html.ep -->
<!DOCTYPE html>
<html>
<head>
    <title><%= title %></title>
    <meta charset="utf-8">
    <%= content 'head' %>  <!-- For additional head content -->
</head>
<body>
    <header>...</header>
    <main><%= content %></main>
    <footer>...</footer>
    <%= content 'footer' %>  <!-- For additional footer scripts -->
</body>
</html>
```

## 🔍 Debugging Template Issues

### Common Problems

**Problem**: Invalid nested HTML
**Cause**: Complete HTML template rendered with layout
**Solution**: Add `layout => 0` to render call

**Problem**: Missing layout elements
**Cause**: Fragment template rendered with `layout => 0`
**Solution**: Remove `layout => 0` from render call

**Problem**: Duplicate meta tags or assets
**Cause**: Both template and layout include same assets
**Solution**: Use `content_for` blocks or reorganize assets

### Debugging Tools

```perl
# Check what layout is being used
say "Layout: " . ($self->stash('layout') || 'default');

# Check template content
say "Template content type: " . ($self->stash('template') =~ /<!DOCTYPE/i ? 'Complete HTML' : 'Fragment');
```

## 📖 Migration Guide

### Converting Complete HTML Templates

If you have existing complete HTML templates that are causing nested HTML issues:

1. **Option 1**: Add `layout => 0` to render calls (recommended for existing templates)
2. **Option 2**: Convert templates to fragments by removing HTML skeleton

### Converting Fragment Templates

If you have fragment templates that need layout features:

1. **Option 1**: Remove `layout => 0` from render calls
2. **Option 2**: Add missing layout elements to template

## 🤝 Contributing Guidelines

When adding new templates:
1. **Decide template type** (complete HTML vs fragment)
2. **Follow consistent structure** for the chosen type
3. **Use appropriate render parameters**
4. **Test in multiple browsers** to ensure proper rendering
5. **Document any special requirements**

## 📝 Template Checklist

- [ ] Template follows correct structure for its type
- [ ] Render call uses appropriate `layout` parameter
- [ ] No duplicate HTML elements (html, head, body)
- [ ] Meta tags and assets are properly organized
- [ ] Template works with and without JavaScript
- [ ] Template is responsive and mobile-friendly
- [ ] Template has been tested in multiple browsers

## 📚 Additional Resources

- [Mojolicious Rendering Documentation](https://docs.mojolicious.org/Mojo/Controller#render)
- [HTML5 Specification](https://html.spec.whatwg.org/)
- [Web Accessibility Guidelines](https://www.w3.org/WAI/standards-guidelines/)

By following these guidelines, you ensure consistent, maintainable, and accessible templates throughout the application.