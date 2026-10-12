/**
 * Original demo content written for Parvoz. Not derived from any published instrument. Demo norms are synthetic.
 *
 * "Kasbiy qiziqishlar": 12 ta ko'p tanlovli savol × 3 variant. Har variant olti
 * yo'nalishdan biriga bog'langan (R, I, A, S, E, C); har yo'nalish aynan 6 marta uchraydi.
 */
import { L, multi, type TemplateContent } from './build';

const ASK: [string, string] = ['Qaysi mashg\'ulot senga yoqadi?', 'Что из этого тебе нравится?'];
const WEEKEND: [string, string] = ['Bo\'sh vaqtingda nima qilishni tanlarding?', 'Чем бы ты занялся(-ась) в свободное время?'];
const CLUB: [string, string] = ['Qaysi to\'garakka yozilarding?', 'В какой кружок ты бы записался(-ась)?'];

export const CAREER: TemplateContent = {
  description: L(
    'Olti yo\'nalish bo\'yicha qiziqishlar: amaliy-texnik, tadqiqotchi, ijodiy, ijtimoiy, tashabbuskor, tartib va hujjat. Kasb tanlash haqida suhbat uchun asos.',
    'Интересы по шести направлениям: практико-технический, исследовательский, творческий, социальный, предприимчивый, порядок и документы. Основа для беседы о выборе профессии.',
  ),
  instructions: L(
    'Har bir savolda o\'zingga yoqadigan mashg\'ulotlarni belgila — bitta yoki bir nechta. Hech biri yoqmasa, tanlamasang ham bo\'ladi.',
    'В каждом вопросе отметь занятия, которые тебе нравятся, — одно или несколько. Если ничего не нравится, можно ничего не выбирать.',
  ),
  items: [
    multi('cr1', ASK, [
      ['R', 'Velosipedni ta\'mirlash', 'Чинить велосипед'],
      ['I', 'Tajriba o\'tkazib, natijasini kuzatish', 'Проводить опыт и наблюдать за результатом'],
      ['A', 'Rasm chizish yoki dizayn o\'ylab topish', 'Рисовать или придумывать дизайн'],
    ]),
    multi('cr2', CLUB, [
      ['E', 'Sinf tadbirini tashkil qilish', 'Организовать классное мероприятие'],
      ['S', 'Kichiklarga darsda yordam berish', 'Помогать младшим с уроками'],
      ['C', 'Kutubxona katalogini tartibga solish', 'Наводить порядок в каталоге библиотеки'],
    ]),
    multi('cr3', WEEKEND, [
      ['S', 'Yangi kelgan sinfdoshga maktabni tanishtirish', 'Познакомить новичка со школой'],
      ['R', 'Bog\'da daraxt ekish va parvarish qilish', 'Сажать деревья и ухаживать за садом'],
      ['E', 'Do\'stlarni yangi g\'oyaga qiziqtirish', 'Увлечь друзей новой идеей'],
    ]),
    multi('cr4', ASK, [
      ['A', 'Qo\'shiq yoki she\'r yozish', 'Сочинять песню или стихи'],
      ['C', 'Jadval tuzib, xarajatlarni hisoblash', 'Составлять таблицу и считать расходы'],
      ['I', 'Osmon nega ko\'k ekanini o\'rganish', 'Выяснять, почему небо голубое'],
    ]),
    multi('cr5', CLUB, [
      ['A', 'Sahnada rol ijro etish', 'Играть роль на сцене'],
      ['R', 'Yog\'ochdan buyum yasash', 'Мастерить вещи из дерева'],
      ['C', 'Hujjatlarni papkalarga tartib bilan joylash', 'Раскладывать документы по папкам'],
    ]),
    multi('cr6', WEEKEND, [
      ['I', 'Mantiqiy jumboqlar yechish', 'Решать логические головоломки'],
      ['E', 'Kichik biznes rejasini tuzish', 'Составлять план небольшого бизнеса'],
      ['S', 'Xafa bo\'lgan do\'stni tinglab, qo\'llab-quvvatlash', 'Выслушать и поддержать друга, которому грустно'],
    ]),
    multi('cr7', ASK, [
      ['E', 'Maktab yarmarkasida qo\'l ishlarini sotish', 'Продавать поделки на школьной ярмарке'],
      ['R', 'Elektr zanjirini yig\'ish', 'Собирать электрическую схему'],
      ['I', 'Hayvonlar xulqini kuzatib, yozib borish', 'Наблюдать за поведением животных и записывать'],
    ]),
    multi('cr8', CLUB, [
      ['C', 'Tadbir uchun ro\'yxat va jadval tuzish', 'Составлять списки и расписание для мероприятия'],
      ['A', 'Video yoki foto loyiha tayyorlash', 'Снимать видео или фотопроект'],
      ['S', 'Volontyor bo\'lib keksalarga yordam berish', 'Помогать пожилым людям как волонтёр'],
    ]),
    multi('cr9', WEEKEND, [
      ['R', 'Uydagi texnikani o\'rnatish va sozlash', 'Устанавливать и настраивать технику дома'],
      ['C', 'Ma\'lumotlarni kompyuterga aniq kiritish', 'Аккуратно вносить данные в компьютер'],
      ['S', 'Jamoada hamma bilan til topishish', 'Находить общий язык со всеми в команде'],
    ]),
    multi('cr10', ASK, [
      ['E', 'Sinf sardori bo\'lish', 'Быть старостой класса'],
      ['I', 'Ilmiy-ommabop kitob yoki ensiklopediya o\'qish', 'Читать научно-популярные книги или энциклопедию'],
      ['A', 'Sinf bezagini o\'ylab topish', 'Придумывать оформление класса'],
    ]),
    multi('cr11', CLUB, [
      ['R', 'Robot yoki model yig\'ish', 'Собирать робота или модель'],
      ['E', 'Munozarada o\'z fikrini himoya qilish', 'Защищать своё мнение в дебатах'],
      ['A', 'Musiqa asbobini chalish', 'Играть на музыкальном инструменте'],
    ]),
    multi('cr12', WEEKEND, [
      ['S', 'Sinfdoshlarga qiyin mavzuni tushuntirish', 'Объяснять одноклассникам трудную тему'],
      ['I', 'Tabiat hodisalarini tushuntirishga urinish', 'Пытаться объяснить явления природы'],
      ['C', 'Qoidalar va tartibga aniq amal qilish', 'Чётко следовать правилам и порядку'],
    ]),
  ],
};
