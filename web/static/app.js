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
            name:            editTarget?.name           || '',
            emoji:           editTarget?.emoji          || '🥩',
            color:           editTarget?.color          || '#C0392B',
            created_at:      editTarget?.created_at     || new Date().toISOString().split('T')[0],
            weight_per_cube: editTarget?.weight_per_cube || 20,
            total_cubes:     editTarget?.total_cubes    || 10,
            unit_type:       editTarget?.unit_type      || 'weight',
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
            const isLow     = i => i.current_cubes <= 3;
            const isWhite   = i => (i.color || '').toUpperCase() === '#FFFFFF';

            const bgFor     = i => isLow(i) ? '#e74c3cBB' : isWhite(i) ? '#E0E0E0BB' : (i.color || '#888') + 'BB';
            const borderFor = i => isLow(i) ? '#e74c3c'   : isWhite(i) ? '#555555'   : (i.color || '#888');
            const labelFor  = i => {
                const grams = i.unit_type === 'weight' && i.weight_per_cube
                    ? `  ${i.current_cubes * i.weight_per_cube}g` : '';
                return `${i.emoji} ${i.name}${grams}`;
            };

            this._chart = new Chart(canvas, {
                type: 'bar',
                data: {
                    labels: sorted.map(i => labelFor(i)),
                    datasets: [{
                        data: sorted.map(i => i.current_cubes),
                        backgroundColor: sorted.map(i => bgFor(i)),
                        borderColor:     sorted.map(i => borderFor(i)),
                        borderWidth: sorted.map(i => isWhite(i) ? 2 : 1),
                        borderRadius: 5,
                    }],
                },
                options: {
                    indexAxis: 'y',
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: { callbacks: {
                            label: ctx => {
                                const ing = sorted[ctx.dataIndex];
                                if (ing.unit_type === 'weight' && ing.weight_per_cube) {
                                    return ` ${ctx.raw}개 · ${ctx.raw * ing.weight_per_cube}g`;
                                }
                                return ` ${ctx.raw}개`;
                            },
                        }},
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

// ─── 식단표 (캘린더) ───
const MEAL_LABELS = { morning:'아침', morning_snack:'오전간식', lunch:'점심', snack:'오후간식', dinner:'저녁', tried:'알러지 테스트' };
const MEAL_ORDER  = ['morning','morning_snack','lunch','snack','dinner'];

function schedulePage() {
    return {
        meals: [],
        ingredients: [],
        viewDate: new Date(),
        selectedMeal: null,
        showAddModal: false,
        showEditModal: false,
        editMealData: null,
        addDefaultDate: '',
        addDefaultMealTime: 'morning',
        _today: new Date(),
        checkedIngredients: {},

        async init() {
            const t = new Date();
            this.viewDate = new Date(t.getFullYear(), t.getMonth(), 1);
            await this.load();
        },

        async load() {
            [this.meals, this.ingredients] = await Promise.all([
                api('/api/meals')       || [],
                api('/api/ingredients') || [],
            ]);
        },

        get viewYear()  { return this.viewDate.getFullYear(); },
        get viewMonth() { return this.viewDate.getMonth(); },
        get viewMonthLabel() { return `${this.viewYear}년 ${this.viewMonth + 1}월`; },

        prevMonth() { this.viewDate = new Date(this.viewYear, this.viewMonth - 1, 1); },
        nextMonth() { this.viewDate = new Date(this.viewYear, this.viewMonth + 1, 1); },
        goToday()   {
            const t = new Date();
            this.viewDate = new Date(t.getFullYear(), t.getMonth(), 1);
        },

        get calendarDays() {
            const y = this.viewYear, m = this.viewMonth;
            const firstDow  = new Date(y, m, 1).getDay();
            const daysInMon = new Date(y, m + 1, 0).getDate();
            const prevLast  = new Date(y, m, 0).getDate();
            const cells = [];
            for (let i = firstDow - 1; i >= 0; i--)
                cells.push({ d: new Date(y, m - 1, prevLast - i), other: true });
            for (let d = 1; d <= daysInMon; d++)
                cells.push({ d: new Date(y, m, d), other: false });
            while (cells.length % 7 !== 0)
                cells.push({ d: new Date(y, m + 1, cells.length - firstDow - daysInMon + 1), other: true });
            return cells;
        },

        _dateStr(date) {
            return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
        },

        get _mealMap() {
            const m = {};
            for (const meal of this.meals) m[`${meal.date}|${meal.meal_time}`] = meal;
            return m;
        },

        mealAt(date, mealTime) {
            return this._mealMap[`${this._dateStr(date)}|${mealTime}`] || null;
        },

        clickSlot(date, mealTime) {
            const meal = this.mealAt(date, mealTime);
            if (meal) this.openDetail(meal);
            else      this.openAddMeal(this._dateStr(date), mealTime);
        },

        isToday(date) {
            const t = this._today;
            return date.getFullYear() === t.getFullYear() &&
                   date.getMonth()    === t.getMonth()    &&
                   date.getDate()     === t.getDate();
        },

        openDetail(meal)  {
            this.selectedMeal = { ...meal, ingredients: meal.ingredients || [] };
            this.checkedIngredients = {};
        },
        closeDetail()     { this.selectedMeal = null; this.checkedIngredients = {}; },

        toggleCheck(id)   { this.checkedIngredients[id] = !this.checkedIngredients[id]; },
        isChecked(id)     { return !!this.checkedIngredients[id]; },

        get anyChecked() {
            return Object.values(this.checkedIngredients).some(Boolean);
        },

        get checkedMealGrams() {
            if (!this.selectedMeal) return 0;
            return (this.selectedMeal.ingredients || [])
                .filter(mi => mi.unit_type !== 'quantity' && this.checkedIngredients[mi.ingredient_id])
                .reduce((sum, mi) => sum + mi.grams, 0);
        },

        openEditMeal(meal) {
            this.editMealData = { ...meal, ingredients: meal.ingredients || [] };
            this.showEditModal = true;
        },

        async onMealEdited() {
            this.showEditModal = false;
            this.editMealData = null;
            this.selectedMeal = null;
            await this.load();
        },

        openAddMeal(date, mealTime = 'morning') {
            this.addDefaultDate     = date || this._dateStr(new Date());
            this.addDefaultMealTime = mealTime;
            this.showAddModal = true;
        },

        async changeStatus(meal, status) {
            const updated = await api(`/api/meals/${meal.id}/status`,
                { method: 'POST', body: { status } });
            if (updated) {
                const idx = this.meals.findIndex(m => m.id === meal.id);
                if (idx !== -1) this.meals[idx] = updated;
                this.selectedMeal = { ...updated, ingredients: updated.ingredients || [] };
                this.ingredients  = await api('/api/ingredients') || [];
            }
        },

        async deleteMeal(meal) {
            if (!confirm(`${meal.date} ${MEAL_LABELS[meal.meal_time]} 식단을 삭제할까요?`)) return;
            const res = await api(`/api/meals/${meal.id}`, { method: 'DELETE' });
            if (res?.ok) { await this.load(); this.selectedMeal = null; }
        },

        async onMealSaved() { this.showAddModal = false; await this.load(); },

        statusBadge(s) {
            return {
                upcoming:        { cls:'badge-blue',    text:'예정' },
                'auto-consumed': { cls:'badge-success', text:'자동 차감됨' },
                confirmed:       { cls:'badge-success', text:'먹었어요 ✅' },
                skipped:         { cls:'badge-muted',   text:'건너뜀' },
            }[s] || { cls:'badge-muted', text:s };
        },

        chipColor(status) {
            return { upcoming:'#3498db', confirmed:'#27ae60',
                     skipped:'#95a5a6', 'auto-consumed':'#95a5a6' }[status] || '#888';
        },

        detailDateLabel(ds) {
            if (!ds) return '';
            return new Date(ds + 'T00:00:00').toLocaleDateString('ko-KR',
                { year:'numeric', month:'long', day:'numeric', weekday:'long' });
        },

        dayTotalGrams(date) {
            const ds = this._dateStr(date);
            return this.meals
                .filter(m => m.date === ds)
                .flatMap(m => m.ingredients || [])
                .filter(mi => mi.unit_type !== 'quantity')
                .reduce((sum, mi) => sum + mi.grams, 0);
        },

        mealTotalGrams(meal) {
            return (meal.ingredients || [])
                .filter(mi => mi.unit_type !== 'quantity')
                .reduce((sum, mi) => sum + mi.grams, 0);
        },
    };
}

// ─── 식단 만들기 모달 ───
function mealModal(defaultDate, defaultMealTime, ingredients) {
    return {
        date:      defaultDate || new Date().toISOString().split('T')[0],
        mealTime: defaultMealTime || 'morning',
        cubes:    {},
        mealTimes: [
            { value:'morning',       label:'아침' },
            { value:'morning_snack', label:'오전간식' },
            { value:'lunch',         label:'점심' },
            { value:'snack',         label:'오후간식' },
            { value:'dinner',        label:'저녁' },
            { value:'tried',         label:'알러지 테스트' },
        ],
        ingredients,

        get hasIngredients() { return Object.values(this.cubes).some(c => c > 0); },

        _cubesToGrams(ingId, cubeCount) {
            const ing = this.ingredients.find(i => i.id === ingId);
            if (!ing) return cubeCount;
            return ing.unit_type === 'weight' ? cubeCount * ing.weight_per_cube : cubeCount;
        },

        async submit() {
            const items = Object.entries(this.cubes)
                .filter(([, c]) => c > 0)
                .map(([id, c]) => ({ ingredient_id: parseInt(id), grams: this._cubesToGrams(parseInt(id), c) }));
            if (!items.length) return;
            await api('/api/meals', {
                method:'POST',
                body:{ date: this.date, meal_time: this.mealTime, ingredients: items }
            });
            this.$dispatch('meal-saved');
        },
    };
}

// ─── 식단 수정 모달 ───
function editMealModal(meal, ingredients) {
    const initCubes = {};
    for (const mi of (meal.ingredients || [])) {
        initCubes[mi.ingredient_id] = mi.unit_type === 'weight'
            ? Math.round(mi.grams / mi.weight_per_cube)
            : mi.grams;
    }
    return {
        mealId:   meal.id,
        date:     meal.date,
        mealTime: meal.meal_time,
        cubes:    { ...initCubes },
        mealTimes: [
            { value:'morning',       label:'아침' },
            { value:'morning_snack', label:'오전간식' },
            { value:'lunch',         label:'점심' },
            { value:'snack',         label:'오후간식' },
            { value:'dinner',        label:'저녁' },
            { value:'tried',         label:'알러지 테스트' },
        ],
        ingredients,

        get hasIngredients() { return Object.values(this.cubes).some(c => c > 0); },

        _cubesToGrams(ingId, cubeCount) {
            const ing = this.ingredients.find(i => i.id === ingId);
            if (!ing) return cubeCount;
            return ing.unit_type === 'weight' ? cubeCount * ing.weight_per_cube : cubeCount;
        },

        async submit() {
            const items = Object.entries(this.cubes)
                .filter(([, c]) => c > 0)
                .map(([id, c]) => ({ ingredient_id: parseInt(id), grams: this._cubesToGrams(parseInt(id), c) }));
            if (!items.length) return;
            await api(`/api/meals/${this.mealId}`, {
                method: 'PUT',
                body: { date: this.date, meal_time: this.mealTime, ingredients: items },
            });
            this.$dispatch('meal-edited');
        },
    };
}

// ─── 알러지 테스트 ───
const ALLERGY_EMOJIS = [
    '🧪','🥕','🥦','🌽','🍠','🥔','🎃','🥬','🧅','🧄',
    '🥩','🍗','🐟','🥚','🧀','🍎','🍊','🫐','🍓','🍌',
    '🥝','🍆','🍅','🥒','🫛','🥜','🌰','🫜','🍖','🦐',
];

function allergyPage() {
    return {
        tests: [],
        viewDate: new Date(),
        showAddModal: false,
        showDetailModal: false,
        selectedTest: null,
        addDate: '',
        form: { emoji: '🧪', ingredient_name: '', memo: '' },
        presetEmojis: ALLERGY_EMOJIS,
        _today: new Date(),

        async init() {
            const t = new Date();
            this.viewDate = new Date(t.getFullYear(), t.getMonth(), 1);
            await this.load();
        },

        async load() {
            this.tests = await api('/api/allergy') || [];
        },

        get viewYear()  { return this.viewDate.getFullYear(); },
        get viewMonth() { return this.viewDate.getMonth(); },
        get viewMonthLabel() { return `${this.viewYear}년 ${this.viewMonth + 1}월`; },

        prevMonth() { this.viewDate = new Date(this.viewYear, this.viewMonth - 1, 1); },
        nextMonth() { this.viewDate = new Date(this.viewYear, this.viewMonth + 1, 1); },
        goToday() {
            const t = new Date();
            this.viewDate = new Date(t.getFullYear(), t.getMonth(), 1);
        },

        get calendarDays() {
            const y = this.viewYear, m = this.viewMonth;
            const firstDow  = new Date(y, m, 1).getDay();
            const daysInMon = new Date(y, m + 1, 0).getDate();
            const prevLast  = new Date(y, m, 0).getDate();
            const cells = [];
            for (let i = firstDow - 1; i >= 0; i--)
                cells.push({ d: new Date(y, m - 1, prevLast - i), other: true });
            for (let d = 1; d <= daysInMon; d++)
                cells.push({ d: new Date(y, m, d), other: false });
            while (cells.length % 7 !== 0)
                cells.push({ d: new Date(y, m + 1, cells.length - firstDow - daysInMon + 1), other: true });
            return cells;
        },

        _dateStr(date) {
            return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
        },

        testsOnDate(date) {
            const ds = this._dateStr(date);
            return this.tests.filter(t => t.test_date === ds);
        },

        isToday(date) {
            const t = this._today;
            return date.getFullYear() === t.getFullYear() &&
                   date.getMonth()    === t.getMonth()    &&
                   date.getDate()     === t.getDate();
        },

        openAdd(date) {
            this.addDate = this._dateStr(date);
            this.form = { emoji: '🧪', ingredient_name: '', memo: '' };
            this.showAddModal = true;
        },

        openDetail(test) {
            this.selectedTest = test;
            this.showDetailModal = true;
        },

        async submit() {
            if (!this.form.ingredient_name.trim()) return;
            const res = await api('/api/allergy', {
                method: 'POST',
                body: { ...this.form, test_date: this.addDate },
            });
            if (res && res.id) {
                this.tests = [...this.tests, res];
                this.showAddModal = false;
            }
        },

        async deleteTest(test) {
            if (!confirm(`"${test.ingredient_name}" 기록을 삭제할까요?`)) return;
            const res = await api(`/api/allergy/${test.id}`, { method: 'DELETE' });
            if (res?.ok) {
                this.tests = this.tests.filter(t => t.id !== test.id);
                this.showDetailModal = false;
                this.selectedTest = null;
            }
        },

        dateLabel(ds) {
            if (!ds) return '';
            return new Date(ds + 'T00:00:00').toLocaleDateString('ko-KR',
                { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' });
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

        notify: { enabled: false, notify_hour: 8, notify_minute: 0, notify_threshold: 3, discord_webhook: '' },
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

        async runNotify() {
            this.notifyMsg = '';
            const r = await api('/api/notification-settings/run', { method: 'POST' });
            if (r?.ok) {
                this.notifyOk = true;
                this.notifyMsg = r.sent ? `발송 완료 (${r.count}개 항목) 📨` : '재고 부족 항목 없음 ✅';
            } else {
                this.notifyOk = false;
                this.notifyMsg = r?.error || '실행 실패';
            }
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
