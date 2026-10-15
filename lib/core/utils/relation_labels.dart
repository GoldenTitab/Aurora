String relationLabelFa(String? relation) {
  switch (relation) {
    case 'SEQUEL':
      return 'دنباله';
    case 'PREQUEL':
      return 'پیش‌درآمد';
    case 'SIDE_STORY':
      return 'داستان فرعی';
    case 'SPIN_OFF':
      return 'اسپین‌آف';
    case 'SUMMARY':
      return 'خلاصه';
    case 'ALTERNATIVE':
      return 'نسخه جایگزین';
    case 'CHARACTER':
      return 'شخصیت';
    case 'OTHER':
      return 'مرتبط';
    case 'PARENT':
      return 'والد';
    case 'ADAPTATION':
      return 'اقتباس';
    default:
      return relation ?? '';
  }
}
