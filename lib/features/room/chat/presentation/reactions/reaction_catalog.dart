class ReactionDefinition {
  const ReactionDefinition.emoji({required this.id, required this.emoji})
    : assetPath = null;

  const ReactionDefinition.asset({required this.id, required this.assetPath})
    : emoji = null;

  final String id;

  final String? emoji;
  final String? assetPath;

  bool get isAsset => assetPath != null;
}

abstract final class ReactionCatalog {
  static const List<ReactionDefinition> all = [
    ReactionDefinition.emoji(id: 'heart', emoji: '❤️'),
    ReactionDefinition.emoji(id: 'fire', emoji: '🔥'),
    ReactionDefinition.asset(
      id: 'fire_happy',
      assetPath: 'assets/reactions/fire_happy.webp',
    ),
    ReactionDefinition.asset(
      id: 'fire_excited',
      assetPath: 'assets/reactions/fire_excited.webp',
    ),

    ReactionDefinition.asset(
      id: 'fire_love',
      assetPath: 'assets/reactions/fire_love.webp',
    ),
    ReactionDefinition.asset(
      id: 'fire_shy',
      assetPath: 'assets/reactions/fire_shy.webp',
    ),
    ReactionDefinition.asset(
      id: 'fire_angry',
      assetPath: 'assets/reactions/fire_angry.webp',
    ),
    ReactionDefinition.asset(
      id: 'fire_surprised',
      assetPath: 'assets/reactions/fire_surprised.webp',
    ),
    ReactionDefinition.asset(
      id: 'fire_sleepy',
      assetPath: 'assets/reactions/fire_sleepy.webp',
    ),
    ReactionDefinition.asset(
      id: 'fire_party',
      assetPath: 'assets/reactions/fire_party.webp',
    ),
    ReactionDefinition.asset(
      id: 'cat_happy',
      assetPath: 'assets/reactions/cat_happy.webp',
    ),
    ReactionDefinition.asset(
      id: 'cat_wink',
      assetPath: 'assets/reactions/cat_wink.webp',
    ),
    ReactionDefinition.asset(
      id: 'cat_love',
      assetPath: 'assets/reactions/cat_love.webp',
    ),
    ReactionDefinition.asset(
      id: 'cat_sleepy',
      assetPath: 'assets/reactions/cat_sleepy.webp',
    ),
    ReactionDefinition.asset(
      id: 'dog_happy',
      assetPath: 'assets/reactions/dog_happy.webp',
    ),
    ReactionDefinition.asset(
      id: 'dog_shy',
      assetPath: 'assets/reactions/dog_shy.webp',
    ),
    ReactionDefinition.asset(
      id: 'dog_laugh',
      assetPath: 'assets/reactions/dog_laugh.webp',
    ),
    ReactionDefinition.asset(
      id: 'dog_surprised',
      assetPath: 'assets/reactions/dog_surprised.webp',
    ),
    ReactionDefinition.asset(
      id: 'horse_happy',
      assetPath: 'assets/reactions/horse_happy.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_excited',
      assetPath: 'assets/reactions/horse_excited.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_love',
      assetPath: 'assets/reactions/horse_love.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_blush',
      assetPath: 'assets/reactions/horse_blush.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_angry',
      assetPath: 'assets/reactions/horse_angry.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_surprised',
      assetPath: 'assets/reactions/horse_surprised.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_sleep',
      assetPath: 'assets/reactions/horse_sleep.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_party',
      assetPath: 'assets/reactions/horse_party.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_wink',
      assetPath: 'assets/reactions/horse_wink.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_laugh',
      assetPath: 'assets/reactions/horse_laugh.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_curious',
      assetPath: 'assets/reactions/horse_curious.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_proud',
      assetPath: 'assets/reactions/horse_proud.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_sad',
      assetPath: 'assets/reactions/horse_sad.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_playful',
      assetPath: 'assets/reactions/horse_playful.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_amazed',
      assetPath: 'assets/reactions/horse_amazed.webp',
    ),

    ReactionDefinition.asset(
      id: 'horse_calm',
      assetPath: 'assets/reactions/horse_calm.webp',
    ),
  ];

  static ReactionDefinition? find(String id) {
    for (final reaction in all) {
      if (reaction.id == id) {
        return reaction;
      }
    }

    return null;
  }

  static int indexOf(String id) {
    return all.indexWhere((reaction) => reaction.id == id);
  }
}
