/* ─── 치밀한 이유식 — Alpine.js Components ─── */

function emojiToCdnUrl(emoji) {
    const cp = [...emoji]
        .filter(c => c.codePointAt(0) !== 0xFE0F)
        .map(c => c.codePointAt(0).toString(16))
        .join('-');
    return `https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/72x72/${cp}.png`;
}

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

        async deleteIngredient(ing) {
            if (!confirm(`"${ing.name}" 재료를 삭제할까요?\n관련된 식단 기록에서도 제거됩니다.`)) return;
            const res = await api(`/api/ingredients/${ing.id}`, { method: 'DELETE' });
            if (res && res.ok) {
                this.ingredients = this.ingredients.filter(i => i.id !== ing.id);
            }
        },

        async onSaved() {
            this.showAddModal = false;
            this.editTarget = null;
            await this.load();
        },
    };
}

// ─── 재료 모달 ───
const PRESET_EMOJIS = ['🥩','🐟','🥕','🥦','🌽','🍠','🥬','🫜','🫑','🧅','🍗','🥚','🧀','🍖','🫛','🥑'];
const PRESET_COLORS = ['#C0392B','#E67E22','#F1C40F','#27AE60','#2980B9','#8E44AD','#1ABC9C','#E74C3C','#FFFFFF'];

const EMOJI_DATA = [
    // 육류
    {e:'🥩',n:'고기 소고기 육류 스테이크 beef meat'},
    {e:'🍖',n:'뼈 고기 갈비 돼지 bone meat'},
    {e:'🍗',n:'닭 치킨 닭다리 chicken'},
    {e:'🥓',n:'베이컨 돼지고기 삼겹살 bacon pork'},
    {e:'🐖',n:'돼지 pork pig'},
    {e:'🐄',n:'소 beef cow'},
    {e:'🦆',n:'오리 duck'},
    {e:'🦃',n:'칠면조 turkey'},
    // 해산물
    {e:'🐟',n:'생선 물고기 어류 fish'},
    {e:'🐡',n:'복어 생선 fish'},
    {e:'🐠',n:'열대어 생선 fish'},
    {e:'🐬',n:'돌고래 dolphin'},
    {e:'🦐',n:'새우 shrimp prawn'},
    {e:'🦑',n:'오징어 squid'},
    {e:'🦀',n:'게 크랩 crab'},
    {e:'🦞',n:'랍스터 가재 lobster'},
    {e:'🦪',n:'굴 oyster'},
    {e:'🐙',n:'문어 octopus'},
    // 채소
    {e:'🥕',n:'당근 carrot'},
    {e:'🥦',n:'브로콜리 broccoli'},
    {e:'🌽',n:'옥수수 corn'},
    {e:'🍠',n:'고구마 sweet potato'},
    {e:'🥔',n:'감자 potato'},
    {e:'🎃',n:'호박 단호박 애호박 늙은호박 pumpkin squash'},
    {e:'🥬',n:'청경채 시금치 상추 채소 leafy green'},
    {e:'🫜',n:'무 무우 radish daikon 뿌리채소 turnip beet root vegetable'},
    {e:'🥗',n:'샐러드 salad'},
    {e:'🫑',n:'파프리카 피망 bell pepper'},
    {e:'🌶️',n:'고추 chili pepper'},
    {e:'🧅',n:'양파 onion'},
    {e:'🧄',n:'마늘 garlic'},
    {e:'🫛',n:'완두콩 pea pod'},
    {e:'🫘',n:'콩 bean'},
    {e:'🥜',n:'땅콩 peanut'},
    {e:'🌰',n:'밤 chesnut'},
    {e:'🥑',n:'아보카도 avocado'},
    {e:'🍆',n:'가지 eggplant'},
    {e:'🍅',n:'토마토 tomato'},
    {e:'🥒',n:'오이 cucumber'},
    {e:'🌿',n:'허브 herb'},
    {e:'🌱',n:'새싹 sprout'},
    {e:'🪴',n:'식물 plant'},
    {e:'🍃',n:'잎 leaf'},
    {e:'🍄',n:'버섯 mushroom'},
    {e:'🧅',n:'양파 대파 onion'},
    // 과일
    {e:'🍎',n:'사과 apple'},
    {e:'🍐',n:'배 pear'},
    {e:'🍊',n:'귤 오렌지 orange tangerine'},
    {e:'🍋',n:'레몬 lemon'},
    {e:'🍇',n:'포도 grape'},
    {e:'🍓',n:'딸기 strawberry'},
    {e:'🫐',n:'블루베리 blueberry'},
    {e:'🍑',n:'복숭아 peach'},
    {e:'🍒',n:'체리 cherry'},
    {e:'🍌',n:'바나나 banana'},
    {e:'🥭',n:'망고 mango'},
    {e:'🍍',n:'파인애플 pineapple'},
    {e:'🥝',n:'키위 kiwi'},
    {e:'🍈',n:'멜론 melon'},
    {e:'🍉',n:'수박 watermelon'},
    {e:'🫒',n:'올리브 olive'},
    {e:'🍑',n:'살구 apricot peach'},
    // 유제품 / 달걀
    {e:'🥚',n:'달걀 계란 egg'},
    {e:'🍳',n:'달걀 후라이 계란 fried egg'},
    {e:'🧀',n:'치즈 cheese'},
    {e:'🥛',n:'우유 milk'},
    {e:'🧈',n:'버터 butter'},
    {e:'🍦',n:'아이스크림 요거트 yogurt'},
    // 곡물 / 밥
    {e:'🌾',n:'쌀 밀 곡물 rice wheat grain'},
    {e:'🍚',n:'밥 rice'},
    {e:'🍜',n:'국수 면 noodle'},
    {e:'🥣',n:'오트밀 죽 porridge oatmeal'},
    {e:'🍞',n:'빵 bread'},
    {e:'🥐',n:'크루아상 croissant'},
    // 조미료 / 소스
    {e:'🧂',n:'소금 salt'},
    {e:'🍯',n:'꿀 honey'},
    {e:'🫙',n:'저장 sauce jar'},
    {e:'🛢️',n:'오일 기름 oil'},
    // 음료
    {e:'💧',n:'물 water'},
    {e:'🍵',n:'차 tea'},
    {e:'🧃',n:'주스 juice'},
];

// ─── emojibase lazy-loader (모달 열릴 때 1회 fetch, 이후 캐시) ───
let _emojibaseCache = null;
async function loadEmojibaseData() {
    if (_emojibaseCache) return _emojibaseCache;
    try {
        const r = await fetch('https://cdn.jsdelivr.net/npm/emojibase-data@7/en/compact.json');
        _emojibaseCache = await r.json(); // [{emoji, label, tags:[...]}, ...]
    } catch {
        _emojibaseCache = [];
    }
    return _emojibaseCache;
}

function ingredientModal(editTarget) {
    return {
        form: {
            name:           editTarget?.name           || '',
            emoji:          editTarget?.emoji          || '🥩',
            color:          editTarget?.color          || '#C0392B',
            created_at:     editTarget?.created_at     || new Date().toISOString().split('T')[0],
            weight_per_cube: editTarget?.weight_per_cube || 20,
            total_cubes:    editTarget?.total_cubes    || 10,
            unit_type:      editTarget?.unit_type      || 'weight',
        },
        editId:       editTarget?.id || null,
        presetEmojis: PRESET_EMOJIS,
        presetColors: PRESET_COLORS,
        emojiSearch:  '',
        emojibaseAll: [],
        emojibaseReady: false,
        emojibaseLoading: false,

        async init() {
            this.loadEmojis();
        },

        async loadEmojis() {
            if (this.emojibaseReady || this.emojibaseLoading) return;
            this.emojibaseLoading = true;
            this.emojibaseAll = await loadEmojibaseData();
            this.emojibaseLoading = false;
            this.emojibaseReady = true;
        },

        get displayEmojis() {
            const q = this.emojiSearch.trim().toLowerCase();
            if (!q) return this.presetEmojis;

            const seen = new Set();
            const results = [];

            // 한국어 EMOJI_DATA 우선 검색
            for (const item of EMOJI_DATA) {
                if (item.n.toLowerCase().includes(q) && !seen.has(item.e)) {
                    seen.add(item.e);
                    results.push(item.e);
                }
            }

            // emojibase 영문 검색 (label + tags)
            for (const item of this.emojibaseAll) {
                if (results.length >= 80) break;
                const text = (item.label + ' ' + (item.tags || []).join(' ')).toLowerCase();
                if (text.includes(q) && !seen.has(item.emoji)) {
                    seen.add(item.emoji);
                    results.push(item.emoji);
                }
            }

            return results;
        },

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

// ─── 통계 ───
function statsPage() {
    return {
        ingredients: [],
        _chart: null,

        async init() {
            this.ingredients = await api('/api/ingredients') || [];
            this._renderChart();
        },

        get totalCubes() {
            return this.ingredients.reduce((s, i) => s + (i.current_cubes || 0), 0);
        },

        get lowStockCount() {
            return this.ingredients.filter(i => i.current_cubes <= 3).length;
        },

        _renderChart() {
            const canvas = document.getElementById('stockChart');
            if (!canvas || !this.ingredients.length) return;
            if (this._chart) this._chart.destroy();

            const sorted = [...this.ingredients].sort((a, b) => b.current_cubes - a.current_cubes);
            const isLow  = i => i.current_cubes <= 3;

            this._chart = new Chart(canvas, {
                type: 'bar',
                data: {
                    labels: sorted.map(i => `${i.emoji} ${i.name}`),
                    datasets: [{
                        data: sorted.map(i => i.current_cubes),
                        backgroundColor: sorted.map(i => isLow(i) ? '#e74c3cBB' : (i.color || '#888') + 'BB'),
                        borderColor:     sorted.map(i => isLow(i) ? '#e74c3c'   : (i.color || '#888')),
                        borderWidth: 1,
                        borderRadius: 5,
                    }],
                },
                options: {
                    indexAxis: 'y',
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: { callbacks: { label: ctx => ` ${ctx.raw}개` } },
                    },
                    scales: {
                        x: {
                            beginAtZero: true,
                            ticks: { stepSize: 1, color: '#888', font: { size: 11 } },
                            grid: { color: 'rgba(0,0,0,.06)' },
                        },
                        y: {
                            ticks: { color: '#555', font: { size: 12 } },
                            grid: { display: false },
                        },
                    },
                },
            });
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

        async deleteMeal(meal) {
            if (!confirm(`${this.dateLabel(meal.date)} ${this.mealLabel(meal.meal_time)} 식단을 삭제할까요?`)) return;
            await api(`/api/meals/${meal.id}`, { method: 'DELETE' });
            await this.load();
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

// ─── 설정 (관리자) ───
function settingsPage() {
    return {
        users: [],
        showAddModal: false,
        errorMsg: '',
        form: { username: '', password: '', is_admin: false },

        notify: { enabled: false, notify_hour: 8, notify_minute: 0 },
        notifySaving: false,
        notifyMsg: '',
        notifyOk: true,

        async init() {
            await Promise.all([this.load(), this.loadNotify()]);
        },

        async load() {
            this.users = await api('/api/users') || [];
        },

        async loadNotify() {
            const r = await api('/api/notification-settings');
            if (r) this.notify = r;
        },

        async saveNotify() {
            this.notifySaving = true; this.notifyMsg = '';
            const r = await api('/api/notification-settings', { method: 'PUT', body: this.notify });
            this.notifySaving = false;
            if (r?.ok) { this.notifyOk = true; this.notifyMsg = '저장됐어요 ✅'; }
            else        { this.notifyOk = false; this.notifyMsg = r?.error || '저장 실패'; }
            setTimeout(() => this.notifyMsg = '', 3000);
        },

        async testNotify() {
            this.notifyMsg = '';
            const r = await api('/api/notification-settings/test', { method: 'POST' });
            if (r?.ok) { this.notifyOk = true;  this.notifyMsg = '발송 완료 📨'; }
            else        { this.notifyOk = false; this.notifyMsg = r?.error || '발송 실패'; }
            setTimeout(() => this.notifyMsg = '', 4000);
        },

        closeModal() {
            this.showAddModal = false;
            this.form = { username: '', password: '', is_admin: false };
            this.errorMsg = '';
        },

        async addUser() {
            this.errorMsg = '';
            if (!this.form.username || !this.form.password) {
                this.errorMsg = '아이디와 비밀번호를 입력하세요';
                return;
            }
            const res = await api('/api/users', { method: 'POST', body: this.form });
            if (res?.error) { this.errorMsg = res.error; return; }
            this.closeModal();
            await this.load();
        },

        async toggleActive(u) {
            const res = await api(`/api/users/${u.id}/toggle-active`, { method: 'POST' });
            if (res && !res.error) {
                const idx = this.users.findIndex(x => x.id === u.id);
                if (idx !== -1) this.users[idx] = res;
            }
        },

        async deleteUser(u) {
            if (!confirm(`'${u.username}' 계정을 삭제할까요?`)) return;
            const res = await api(`/api/users/${u.id}`, { method: 'DELETE' });
            if (res?.ok) await this.load();
        },
    };
}
