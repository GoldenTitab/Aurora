import '../../core/i18n/lang.dart';
String relationLabelFa(String? relation) {
  switch (relation) {
    case 'SEQUEL':
      return tr('sequel');
    case 'PREQUEL':
      return tr('prequel');
    case 'SIDE_STORY':
      return tr('side_story');
    case 'SPIN_OFF':
      return tr('spin_off');
    case 'SUMMARY':
      return tr('summary');
    case 'ALTERNATIVE':
      return tr('alternative');
    case 'CHARACTER':
      return tr('character');
    case 'OTHER':
      return tr('related');
    case 'PARENT':
      return tr('parent_story');
    case 'ADAPTATION':
      return tr('adaptation');
    case 'COMPILATION':
      return tr('compilation');
    case 'CONTAINS':
      return tr('contains');
    case 'CHILD':
      return tr('child_story');
    default:
      return relation ?? '';
  }
}
