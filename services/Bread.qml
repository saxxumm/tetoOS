pragma Singleton
import QtQuick
import Quickshell

// The bread of the day: once a day Teto hands over a loaf, and the loaf is a
// card — a rarity, a name and a fortune. The ones you have collected are
// counted in the config.
Singleton {
    id: root

    readonly property string today: Qt.formatDate(Sys.now, "yyyy-MM-dd")
    readonly property bool ready: Config.ready && Config.options.breadDay !== root.today
    property var last: null                // the card just opened

    readonly property var cards: [
        { id: "plain", name: "Обычный батон", stars: 1, text: "Хрустит. Это главное." },
        { id: "raisin", name: "Батон с изюмом", stars: 1, text: "Изюм — это сюрприз. Иногда приятный." },
        { id: "rye", name: "Ржаной кирпичик", stars: 1, text: "Тяжёлый, честный, надёжный." },
        { id: "garlic", name: "Чесночный багет", stars: 2, text: "Отпугивает вампиров и коллег." },
        { id: "sesame", name: "Багет с кунжутом", stars: 2, text: "Каждое зёрнышко — маленькая удача." },
        { id: "croissant", name: "Круассан-предатель", stars: 3, text: "Притворялся багетом. Почти получилось." },
        { id: "territory", name: "Багет «Kasane Territory»", stars: 3, text: "Длиной ровно в одну территорию." },
        { id: "drill", name: "Буро-багет", stars: 4, text: "Закручен как хвостики. Сверлит скуку." },
        { id: "golden", name: "Золотой багет", stars: 4, text: "Блестит. Есть жалко, но придётся." },
        { id: "chimera", name: "Химера-багет", stars: 5, text: "Наполовину хлеб, наполовину легенда." }
    ]

    readonly property var fortunes: [
        "Сегодня всё компилируется с первого раза.",
        "Хороший день, чтобы закрыть двадцать вкладок.",
        "Удача: большая. Багетов: много.",
        "Тот самый баг найдётся в первой же строчке.",
        "Музыка сегодня попадёт точно в настроение.",
        "Новые обои принесут новые идеи.",
        "Выспись. Это не совет, это предсказание.",
        "Кто-то сегодня напишет тебе что-то хорошее.",
        "Холст большой — места хватит всем окнам.",
        "Сегодня ты переживёшь любой мердж-конфликт."
    ]

    readonly property int collected: Config.ready ? Object.keys(Config.options.breadBox || {}).length : 0

    function open() {
        if (!root.ready) { root.last = root.last || null; return root.last; }
        const weights = { 1: 50, 2: 28, 3: 14, 4: 6, 5: 2 };
        const pool = [];
        for (const c of root.cards) for (let i = 0; i < weights[c.stars]; i++) pool.push(c);
        const card = Object.assign({}, pool[Math.floor(Math.random() * pool.length)]);
        card.fortune = root.fortunes[Math.floor(Math.random() * root.fortunes.length)];
        const box = Object.assign({}, Config.options.breadBox || {});
        box[card.id] = (box[card.id] || 0) + 1;
        card.count = box[card.id];
        Config.options.breadBox = box;
        Config.options.breadDay = root.today;
        root.last = card;
        Sfx.play("jingle", card.stars >= 4 ? 1.25 : 1);
        return card;
    }
}
