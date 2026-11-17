// Xodim sahifasidagi yozish kartalari: katta "O'zim yozaman" va rolga mos
// shablon kartalari (gradientli ikon bloki, rangli nur, qisqa izoh).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Gradient bilan to'ldirilgan yumaloq-kvadrat ikon (oq belgi, rangli soya).
class SkIconTile extends StatelessWidget {
  const SkIconTile({
    required this.icon,
    required this.color,
    this.size = 46,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(color, Colors.black, 0.35)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, dark],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.38),
            blurRadius: 16,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.48, color: Colors.white),
    );
  }
}

/// "O'zim yozaman" — ko'zga tashlanadigan ko'k karta (erkin xabar).
class WriteOwnCard extends StatelessWidget {
  const WriteOwnCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(22);
    return Semantics(
      button: true,
      label: ContactTopic.other.titleKey.tr(),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3C82FF), Color(0xFF1F5BE0)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: SK.blue.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    SolarIconsBold.pen,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ContactTopic.other.titleKey.tr(),
                        style: skDisplay(16),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ContactTopic.other.hintKey.tr(),
                        style: skText(
                          12.5,
                          c: Colors.white.withValues(alpha: 0.82),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(
                    SolarIconsOutline.arrowRight,
                    size: 18,
                    color: SK.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shablon kartasi: rangli nur, gradient ikon, sarlavha va qisqa izoh.
class TopicCard extends StatelessWidget {
  const TopicCard({required this.topic, required this.onTap, super.key});

  final ContactTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = topicColor(topic);
    final br = BorderRadius.circular(20);
    return Semantics(
      button: true,
      label: topic.titleKey.tr(),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: br,
              color: SK.card,
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: ClipRRect(
              borderRadius: br,
              child: Stack(
                children: [
                  // Yuqori o'ng burchakdagi yumshoq rangli nur.
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.26),
                            color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkIconTile(icon: topicIcon(topic), color: color),
                            const Spacer(),
                            Icon(
                              SolarIconsOutline.arrowRightUp,
                              size: 18,
                              color: color.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          topic.titleKey.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: skText(14.5, w: FontWeight.w600, height: 1.3),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          topic.hintKey.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: skText(11.5, c: SK.dim, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
