class ServiceCategory {
  final String title;
  final String examples;

  const ServiceCategory({
    required this.title,
    required this.examples,
  });
}

class ServiceCategories {
  static const all = <ServiceCategory>[
    ServiceCategory(
      title: 'Покупки и доставка',
      examples: 'Сходить в магазин, забрать заказ.',
    ),
    ServiceCategory(
      title: 'Домашняя помощь',
      examples: 'Уборка, помощь по дому, помощь пожилому человеку.',
    ),
    ServiceCategory(
      title: 'Выгул и уход за животными',
      examples: 'Прогулка с собакой, покормить кота, присмотреть за питомцем.',
    ),
    ServiceCategory(
      title: 'Мелкий ремонт',
      examples: 'Починить кран, повесить полку, заменить лампочку.',
    ),
    ServiceCategory(
      title: 'Переноска и перевозка',
      examples: 'Донести тяжёлые сумки, помочь с переездом.',
    ),
    ServiceCategory(
      title: 'Дети и сопровождение',
      examples: 'Встретить ребёнка, посидеть недолго, проводить до секции.',
    ),
    ServiceCategory(
      title: 'Компьютеры и техника',
      examples: 'Настроить телефон, помочь с ноутбуком, подключить принтер.',
    ),
    ServiceCategory(
      title: 'Документы и формальности',
      examples: 'Помочь оформить заявление, распечатать, отсканировать.',
    ),
    ServiceCategory(
      title: 'Соседская взаимопомощь',
      examples: 'Одолжить инструмент, помочь открыть дверь, присмотреть за квартирой.',
    ),
    ServiceCategory(
      title: 'Транспорт и поездки',
      examples: 'Подвезти, съездить по поручению, помочь добраться.',
    ),
    ServiceCategory(
      title: 'Здоровье и сопровождение',
      examples: 'Сопроводить до поликлиники, помочь купить лекарства.',
    ),
    ServiceCategory(
      title: 'Другое',
      examples: 'Нестандартные бытовые просьбы, которые не подходят под другие категории.',
    ),
  ];

  static List<String> get titles => all.map((category) => category.title).toList();

  static bool contains(String value) {
    final normalized = value.trim();
    return all.any((category) => category.title == normalized);
  }

  static ServiceCategory? byTitle(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    for (final category in all) {
      if (category.title == normalized) {
        return category;
      }
    }
    return null;
  }
}
