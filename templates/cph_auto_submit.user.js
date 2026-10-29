// ==UserScript==
// @name         CPH Auto-Submit (AtCoder & CodeChef)
// @namespace    https://github.com/
// @version      1.0
// @description  Automatically fills and submits code from Neovim into AtCoder, CodeChef, and other judges without manual copy-pasting!
// @match        https://atcoder.jp/contests/*/tasks/*
// @match        https://atcoder.jp/contests/*/submit*
// @match        https://www.codechef.com/problems/*
// @match        https://www.codechef.com/*/problems/*
// @match        https://cses.fi/problemset/submit/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// ==/UserScript==

(function () {
    'use strict';

    const CPH_ENDPOINT = 'http://127.0.0.1:27121/getSubmit';

    function fetchSubmitPayload(cb) {
        if (typeof GM_xmlhttpRequest !== 'undefined') {
            GM_xmlhttpRequest({
                method: 'GET',
                url: CPH_ENDPOINT,
                onload: function (res) {
                    try {
                        const data = JSON.parse(res.responseText);
                        cb(data);
                    } catch (e) {
                        cb(null);
                    }
                },
                onerror: function () {
                    cb(null);
                },
            });
        } else {
            fetch(CPH_ENDPOINT)
                .then((r) => r.json())
                .then((data) => cb(data))
                .catch(() => cb(null));
        }
    }

    function handleAtCoder(payload) {
        const { sourceCode, languageId } = payload;
        console.log('[CPH Auto-Submit] Filling AtCoder submission...');

        // 1. Language Select
        const langSelect = document.querySelector('select[name="data.LanguageId"]');
        if (langSelect && languageId) {
            langSelect.value = languageId.toString();
            langSelect.dispatchEvent(new Event('change', { bubbles: true }));
        }

        // 2. Set Code into Ace Editor & Textarea
        try {
            if (window.ace && typeof window.ace.edit === 'function') {
                const ed = window.ace.edit('editor') || (document.querySelector('.editor') ? window.ace.edit(document.querySelector('.editor')) : null);
                if (ed) ed.setValue(sourceCode, -1);
            }
        } catch (e) {}

        const textarea = document.getElementById('sourceCode') || document.querySelector('textarea[name="sourceCode"]');
        if (textarea) {
            textarea.value = sourceCode;
            textarea.dispatchEvent(new Event('input', { bubbles: true }));
            textarea.dispatchEvent(new Event('change', { bubbles: true }));
        }

        // 3. Auto-click Submit
        setTimeout(() => {
            const submitBtn = document.getElementById('submit') || document.querySelector('button[type="submit"]') || document.querySelector('.btn-submit');
            if (submitBtn) {
                console.log('[CPH Auto-Submit] Clicking Submit...');
                submitBtn.disabled = false;
                submitBtn.click();
            }
        }, 600);
    }

    function handleCodeChef(payload) {
        const { sourceCode } = payload;
        console.log('[CPH Auto-Submit] Filling CodeChef submission...');

        try {
            if (window.monaco && window.monaco.editor) {
                const editors = window.monaco.editor.getEditors ? window.monaco.editor.getEditors() : [];
                if (editors.length > 0) {
                    editors[0].setValue(sourceCode);
                } else {
                    const models = window.monaco.editor.getModels ? window.monaco.editor.getModels() : [];
                    if (models.length > 0) models[0].setValue(sourceCode);
                }
            }
        } catch (e) {}

        setTimeout(() => {
            const buttons = Array.from(document.querySelectorAll('button, input[type="submit"]'));
            const submitBtn = buttons.find((b) => {
                const text = (b.textContent || b.value || '').trim();
                return text === 'Submit' || text === 'Submit Code';
            });
            if (submitBtn) {
                console.log('[CPH Auto-Submit] Clicking Submit...');
                submitBtn.click();
            }
        }, 800);
    }

    // Wait for page to settle, then check for pending submit payload
    setTimeout(() => {
        fetchSubmitPayload((payload) => {
            if (!payload || payload.empty || !payload.sourceCode) return;

            const currentUrl = window.location.href;
            if (currentUrl.includes('atcoder.jp')) {
                handleAtCoder(payload);
            } else if (currentUrl.includes('codechef.com')) {
                handleCodeChef(payload);
            }
        });
    }, 1200);
})();
