/* ─── 치밀한 이유식 — Alpine.js Components ─── */

// ─── API Helper (animation 동일 패턴) ───
async function api(url, options = {}) {
    const defaults = {
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': window._csrfToken || '',
        },
    };
    const opts = { ...defaults, ...options };
    if (options.headers) opts.headers = { ...defaults.headers, ...options.headers };
    if (opts.body && typeof opts.body === 'object') opts.body = JSON.stringify(opts.body);
    let resp;
    try { resp = await fetch(url, opts); }
    catch (e) { console.error('API 오류:', url, e); return null; }
    if (resp.status === 401) { window.location.href = '/login'; return null; }
    try { return await resp.json(); } catch { return null; }
}

// ─── 재고현황 ───
function inventoryPage() {
    return {
        ingredients: [],
        showAddModal: false,
        editTarget: null,

        async init() {
            await api('/api/deduct', { method: 'POST' });
            await this.load();
        },

        async load() {
            this.ingredients = await api('/api/ingredients') || [];
        },

        get lowStockItems() {
            return this.ingredients.filter(i => i.current_cubes <= 3);
        },

        expiryStatus(createdAt) {
            const days = Math.floor((Date.now() - new Date(createdAt)) / 86400000);
            if (days > 30) return 'danger';
            if (days >= 14) return 'warning';
            return 'fresh';
        },

        expiryDays(createdAt) {
            return Math.floor((Date.now() - new Date(createdAt)) / 86400000);
        },

        async adjust(id, delta) {
            const updated = await api(`/api/ingredients/${id}/adjust`, { method: 'POST', body: { delta } });
            if (updated) {
                const idx = this.ingredients.findIndex(i => i.id === id);
                if (idx !== -1) this.ingredients[idx] = updated;
            }
        },

        openEdit(ing) { this.editTarget = { ...ing }; this.showAddModal = true; },
        openAdd()     { this.editTarget = null;        this.showAddModal = true; },

        async onSaved() {
            this.showAddModal = false;
            this.editTarget = null;
            await this.load();
        },
    };
}

// ─── 재료 모달 ───
const PRESET_EMOJIS = ['🥩','🐟','🥕','🥦','🌽','🍠','🥬','🫑','🧅','🍗','🥚','🧀','🍖','🫛','🥑'];
const PRESET_COLORS = ['#C0392B','#E67E22','#F1C40F','#27AE60','#2980B9','#8E44AD','#1ABC9C','#E74C3C'];

function ingredientModal(editTarget) {
    return {
        form: {
            name:           editTarget?.name           || '',
            emoji:          editTarget?.emoji          || '🥩',
            color:          editTarget?.color          || '#C0392B',
            created_at:     editTarget?.created_at     || new Date().toISOString().split('T')[0],
            weight_per_cube: editTarget?.weight_per_cube || 20,
            total_cubes:    editTarget?.total_cubes    || 10,
        },
        editId:       editTarget?.id || null,
        presetEmojis: PRESET_EMOJIS,
        presetColors: PRESET_COLORS,

        async submit() {
            if (this.editId) {
                await api(`/api/ingredients/${this.editId}`, { method: 'PUT', body: this.form });
            } else {
                await api('/api/ingredients', { method: 'POST', body: this.form });
            }
            this.$dispatch('saved');
        },
    };
}

// ─── 식단표 ───
const MEAL_LABELS = { morning:'아침', lunch:'점심', snack:'간식', dinner:'저녁' };
const MEAL_ORDER  = ['morning','lunch','snack','dinner'];

function schedulePage() {
    return {
        meals: [],
        ingredients: [],
        showAddModal: false,
        addDefaultDate: '',

        async init() {
            await api('/api/deduct', { method: 'POST' });
            await this.load();
        },

        async load() {
            [this.meals, this.ingredients] = await Promise.all([
                api('/api/meals')       || [],
                api('/api/ingredients') || [],
            ]);
        },

        get groupedMeals() {
            const g = {};
            for (const m of this.meals) {
                if (!g[m.date]) g[m.date] = [];
                g[m.date].push(m);
            }
            for (const d in g) {
                g[d].sort((a, b) => MEAL_ORDER.indexOf(a.meal_time) - MEAL_ORDER.indexOf(b.meal_time));
            }
            return g;
        },

        get sortedDates() { return Object.keys(this.groupedMeals).sort(); },

        dateLabel(dateStr) {
            const d    = new Date(dateStr + 'T00:00:00');
            const today = new Date(); today.setHours(0,0,0,0);
            const diff  = Math.round((d - today) / 86400000);
            if (diff === 0) return '오늘';
            if (diff === 1) return '내일';
            return d.toLocaleDateString('ko-KR', { month:'long', day:'numeric', weekday:'short' });
        },

        isPast(dateStr) { return new Date(dateStr + 'T23:59:59') < new Date(); },

        mealLabel(t) { return MEAL_LABELS[t] || t; },

        statusBadge(s) {
            return {
                upcoming:        { cls:'badge-blue',    text:'예정' },
                'auto-consumed': { cls:'badge-success', text:'자동 차감됨' },
                confirmed:       { cls:'badge-success', text:'먹었어요 ✅' },
                skipped:         { cls:'badge-muted',   text:'건너뜀' },
            }[s] || { cls:'badge-muted', text:s };
        },

        async setStatus(meal, newStatus) {
            const updated = await api(`/api/meals/${meal.id}/status`,
                { method:'POST', body:{ status: newStatus } });
            if (updated) {
                const idx = this.meals.findIndex(m => m.id === meal.id);
                if (idx !== -1) this.meals[idx] = updated;
                this.ingredients = await api('/api/ingredients') || [];
            }
        },

        openAddMeal(date = '') {
            this.addDefaultDate = date || new Date().toISOString().split('T')[0];
            this.showAddModal = true;
        },

        async onMealSaved() { this.showAddModal = false; await this.load(); },
    };
}

// ─── 식단 추가 모달 ───
function mealModal(defaultDate, ingredients) {
    return {
        date:      defaultDate || new Date().toISOString().split('T')[0],
        mealTime: 'morning',
        grams:    {},
        mealTimes: [
            { value:'morning', label:'아침' },
            { value:'lunch',   label:'점심' },
            { value:'snack',   label:'간식' },
            { value:'dinner',  label:'저녁' },
        ],
        ingredients,

        get hasIngredients() { return Object.values(this.grams).some(g => g > 0); },

        async submit() {
            const items = Object.entries(this.grams)
                .filter(([, g]) => g > 0)
                .map(([id, grams]) => ({ ingredient_id: parseInt(id), grams }));
            if (!items.length) return;
            await api('/api/meals', {
                method:'POST',
                body:{ date: this.date, meal_time: this.mealTime, ingredients: items }
            });
            this.$dispatch('meal-saved');
        },
    };
}
