# Browser Module Pattern

## Module Structure

Export a plain object, not a class. Expose it on `window` for inline onclick handlers.

```js
let App = {};
let $ = sel => document.querySelector(sel);

App.doThing = function(event, id) {
  // ...
};

export default App;
```

## HTML Entry

```html
<script type="module">
  import App from './app.js';
  window.App = App;
  App.init();
</script>
<button onclick="App.doThing(event, this.dataset.id)" data-id="123">Click</button>
```

Key points:
- `window.App = App` exposes the module for inline `onclick` handlers
- Inline `onclick="App.method(event)"` — no `addEventListener` wiring
- `let $ = sel => document.querySelector(sel)` — no `getElementById`

## Async Error Handling

Set `currentEvent` at the top of each async handler so the global rejection handler
can route errors to the right place:

```js
let currentEvent = null;

App.submit = async function(event) {
    currentEvent = event;
    // ... no try/catch
};

// In App.init():
window.addEventListener('unhandledrejection', function(e) {
    let reason;
    if (e.reason instanceof Error) {
        reason = e.reason.message;
    } else {
        reason = String(e.reason);
    }
    if (currentEvent) {
        handleResult(currentEvent, reason, false);
    }
});
```

## Form POST for Redirects

Build forms dynamically rather than hiding them in the markup:

```js
let form    = document.createElement('form');
form.method = 'POST';
form.action = '/some/endpoint';
document.body.appendChild(form);
addHidden(form, 'field_name', value);
form.submit();
```
