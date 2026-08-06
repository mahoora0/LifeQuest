package com.lifequest.quest.service;

import com.lifequest.quest.domain.CompletionType;
import com.lifequest.quest.domain.Quest;
import com.lifequest.quest.domain.QuestGrade;

import org.jspecify.annotations.NonNull;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

/**
 * 트랙 하나의 슬롯을 채우는 추출기(docs/05-business-rules.md §1·§1-B).
 *
 * <h2>계약</h2>
 * <ul>
 *   <li><b>넘긴 인자를 변형하지 않는다.</b> 슬롯 집합도 퀘스트 리스트도 호출자 소유다.
 *       {@code random}만 예외이며, 소비가 그 객체의 계약이기 때문이다.
 *   <li>난수를 주입받으므로 고정 시드로 분포를 반복 검증할 수 있다. 확률 추출은 틀려도
 *       예외도 로그도 없이 조용하므로 반복 실행 외에 드러날 경로가 없다.
 *   <li>슬롯 구성은 호출자가 정한다. 트랙별 구성 차이와 향후 협동 트랙을 여기서 알 필요가 없다.
 * </ul>
 *
 * <h2>추출 절차 — 후보를 먼저 좁히고 등급을 뽑는다</h2>
 * 순서가 뒤집혀 "등급을 먼저 뽑고 풀 전체에서 고른 뒤 불일치를 버리는" 형태가 되면 후보 수가
 * 등급 확률에 곱해져 확률표를 못 지킨다(실측: 일간 LEGENDARY 3% → 0.48%, 주간 RARE 30% → 49%).
 * 편향 방향이 트랙마다 반대여서, 분포를 정하는 것이 확률표가 아니라 시드 구성이 되어 버린다.
 *
 * <h2>완화 3단계 — 순서가 있다</h2>
 * 슬롯 하나를 채우지 못할 때 아래 순서로만 제약을 푼다.
 * <ol>
 *   <li><b>직전 주기 제외를 푼다</b> — {@code completedQuests}에서 뽑는다. 이쪽이 먼저인 이유는
 *       그것이 "우리가 만든 제약"이라 되돌리는 대가가 작기 때문이다.
 *   <li><b>완료 타입 제약을 푼다</b> — 타입 보장 자체를 못 지키는 상황에서만 쓰는 마지막 수단.
 *   <li><b>종료한다</b> — 두 풀이 모두 비었다는 뜻이다.
 * </ol>
 *
 * <p><b>판정은 슬롯이 원하는 타입 단위로 한다.</b> "풀 전체가 비었나"로 ①의 발동을 판정하면,
 * 그 풀에 다른 타입 후보가 남아있는 한 ①은 절대 발동하지 않고 ②가 먼저 걸린다 — 어제 그 타입으로
 * 배정했던 것을 되살리는 대신 엉뚱한 타입으로 대체해 버린다. 판정 단위가 실제 결정 단위보다
 * 거칠면 사다리 순서가 뒤집힌다.
 */
@Component
public class QuestSlotDrawer {
    final double[] GRADE_PERCENTAGE = {0.55, 0.3, 0.12, 0.03};
    static final String COMBINING_STRING = "_combine_";

    /**
     * 풀 하나와 그 {@code <완료타입, 등급>} 버킷 카운트. 추출이 진행되면 둘을 함께 줄인다.
     *
     * <p>인자 리스트를 <b>복사</b>한다. 뽑은 퀘스트를 리스트에서 제거해야 하는데 그 리스트는
     * 호출자 소유다. 원소({@code Quest})는 읽기만 하므로 얕은 복사로 충분하며, 엔티티를
     * 매 호출 복제할 이유는 없다.
     *
     * <p><b>맵과 리스트는 항상 동기다.</b> 카운트가 0이 된 키를 제거하므로 "맵이 비었다"와
     * "리스트가 비었다"가 같은 뜻이 되고, 빈 버킷 판정을 키 존재가 아니라 카운트로 할 수 있다.
     * 마지막 후보를 앞 슬롯이 가져갔을 때 키만 남아 조용히 슬롯이 비는 일을 이것이 막는다.
     */
    static class QuestInformation {
        List<Quest> quests;
        Map<String, Integer> combinedTypeQuestMap = new HashMap<>();

        QuestInformation(List<Quest> quests) {
            this.quests = new ArrayList<>();
            for (Quest quest : quests) {
                this.quests.add(quest);

                String combinedType = combineType(quest);
                combinedTypeQuestMap.put(
                    combinedType,
                    combinedTypeQuestMap.getOrDefault(combinedType, 0) + 1);
            }
        }
    }

    public List<Quest> questDrawer(List<Set<CompletionType>> questSlots, List<Quest> quests, List<Quest> completedQuests) {
        return questDrawer(questSlots, quests, completedQuests, new Random());
    }

    /**
     * 슬롯 목록을 앞에서부터 채운다.
     *
     * @param questSlots      슬롯마다 허용하는 완료 타입. 슬롯 A는 LOCATION, B는 SELF_REPORT,
     *                        C는 타입 제한 없이 잔여에서 고르는 구성을 호출자가 넘긴다.
     *                        <b>원소를 변형하지 않는다</b> — 완화는 슬롯마다 뜨는 복사본에만 적용된다
     * @param quests          이번 주기 후보. 직전 주기 배정분은 호출자가 미리 뺀 상태로 넘긴다
     * @param completedQuests 직전 주기 배정분. 완화 ①에서만 후보가 된다
     * @param random          주입 난수. 같은 시드는 같은 결과를 낸다
     * @return 채워진 슬롯의 퀘스트. 풀이 모자라면 슬롯 수보다 적을 수 있다
     */
    public List<Quest> questDrawer(List<Set<CompletionType>> questSlots, List<Quest> quests, List<Quest> completedQuests, Random random) {

        QuestInformation[] questInformationArr = new QuestInformation[]{new QuestInformation(quests), new QuestInformation(completedQuests)};
        final HashSet<CompletionType> allCompletionTypes = new HashSet<>(Arrays.asList(CompletionType.values()));

        List<Quest> result = new ArrayList<>();
        for (Set<CompletionType> slot : questSlots) {
            // 두 풀이 다 비면 이 슬롯도, 남은 슬롯도 채울 수 없다 — 풀은 슬롯 간에 공유되고
            // 뽑을 때 줄어들기만 하므로 여기서 못 채운 것은 뒤에서도 못 채운다
            boolean allEmpty = true;
            for (QuestInformation questInformation : questInformationArr) {
                if (!questInformation.quests.isEmpty()) {
                    allEmpty = false;
                    break;
                }
            }
            if (allEmpty) {
                return result;
            }

            // 완화는 이 슬롯 하나에만 적용된다. questSlots의 원소를 직접 넓히면 그 슬롯 정의가
            // 영구히 바뀌어, 다음 호출부터 타입 보장이 아무 징후 없이 사라진다.
            // 이 복사본이 아래 모든 타입 판정의 기준이며, slot은 여기서만 읽고 다시 쓰지 않는다
            Set<CompletionType> targetCompletionTypes = new HashSet<>(slot);

            // 완화 ①·② — 어느 풀에서 뽑을지 정한다. 배열 순서가 곧 우선순위이므로
            // quests(제외 적용분)를 먼저 보고, 거기 없을 때만 completedQuests(제외분)로 내려간다.
            // break가 없으면 뒤쪽 원소가 앞을 덮어써 제외가 통째로 무효가 된다
            QuestInformation targetQuestInformation = null;
            while (targetQuestInformation == null) {
                for (QuestInformation questInformation : questInformationArr) {
                    if (isCompletionTypeDrawable(questInformation.combinedTypeQuestMap, targetCompletionTypes)) {
                        targetQuestInformation = questInformation;
                        break;
                    }
                }

                // 탐색 성공 여부를 먼저 본다 — 반환을 가르는 기준은 이 변수 하나뿐이다.
                // 타입 집합의 모양만 보고 반환하면 이미 찾아 둔 후보를 버리게 된다
                if (targetQuestInformation == null) {
                    if (targetCompletionTypes.containsAll(allCompletionTypes)) {
                        // 완화 ③ — 타입을 다 풀고도 없으면 두 풀이 비었다는 뜻이다
                        return result;
                    } else {
                        // 완화 ② — 타입 제약 해제. 복사본만 넓히므로 다음 슬롯은 영향받지 않는다
                        targetCompletionTypes.addAll(allCompletionTypes);
                    }
                }
            }

            // 등급 추출 — 판정 기준은 완화가 반영된 targetCompletionTypes다.
            // 그 안에 없는 등급이 뽑히면 재추첨하며, 이 거부는 "없는 등급의 확률을 0으로 두고
            // 나머지를 비례 재배분"과 수학적으로 같다. 주간 LOCATION 풀에는 NORMAL이 없으므로
            // 55%가 갈 곳을 잃고 30/12/3이 66.7/26.7/6.7로 재배분된다
            QuestGrade selectedGrade;
            while (true) {
                selectedGrade = gradeSelect(random);
                if (!isCombinedTypeDrawable(targetQuestInformation.combinedTypeQuestMap, targetCompletionTypes, selectedGrade)) {
                    continue;
                }
                break;
            }


            // 버킷 안 균등 선택 — 등급이 이미 정해졌으므로 후보 수가 확률에 영향을 주지 않는다.
            // 타입 판정 기준은 여기서도 완화가 반영된 targetCompletionTypes다
            while (true) {
                Quest quest = targetQuestInformation.quests.get(random.nextInt(targetQuestInformation.quests.size()));
                if (!targetCompletionTypes.contains(quest.getCompletionType())) {
                    continue;
                }

                if (!selectedGrade.equals(quest.getGrade())) {
                    continue;
                }

                String combinedType = combineType(quest);
                targetQuestInformation.combinedTypeQuestMap.put(combinedType, targetQuestInformation.combinedTypeQuestMap.get(combinedType) - 1);
                if (targetQuestInformation.combinedTypeQuestMap.get(combinedType) <= 0) {
                    targetQuestInformation.combinedTypeQuestMap.remove(combinedType);
                }

                targetQuestInformation.quests.remove(quest);
                result.add(quest);
                break;
            }
        }

        return result;
    }

    private static boolean isCombinedTypeDrawable(Map<String, Integer> combinedTypeQuestMap, Set<CompletionType> slot, QuestGrade questGrade) {
        for (String combineType : combinedTypeQuestMap.keySet()) {
            for (CompletionType completionType : slot) {
                boolean isDrawable = combineType.equals(combineType(completionType, questGrade))
                    && combinedTypeQuestMap.getOrDefault(combineType, 0) > 0;
                if (isDrawable) {
                    return true;
                }
            }
        }
        return false;
    }

    private static boolean isGradeDrawable(Map<String, Integer> combinedTypeQuestMap, QuestGrade questGrade) {
        for (String combineType : combinedTypeQuestMap.keySet()) {
            boolean isDrawable = combineType.split(COMBINING_STRING)[1].equals(questGrade.toString())
                && combinedTypeQuestMap.getOrDefault(combineType, 0) > 0;
            if (isDrawable) {
                return true;
            }
        }
        return false;
    }

    private static boolean isCompletionTypeDrawable(Map<String, Integer> combinedTypeQuestMap, Set<CompletionType> slot) {
        for (CompletionType targetCompletionType : slot) {
            for (String completionType : combinedTypeQuestMap.keySet()) {
                boolean isDrawable =
                    completionType.split(COMBINING_STRING)[0].equals(targetCompletionType.toString())
                        && combinedTypeQuestMap.get(completionType) > 0;
                if (isDrawable)
                    return true;
            }
        }
        return false;
    }

    private static @NonNull String combineType(CompletionType completionType, QuestGrade questGrade) {
        return "%s%s%s".formatted(completionType.name(), COMBINING_STRING, questGrade.name());
    }

    private static @NonNull String combineType(Quest quest) {
        return combineType(quest.getCompletionType(), quest.getGrade());
    }

    private QuestGrade gradeSelect(Random random) {
        double randomGrade = random.nextDouble();
        double gradeWeight = 0;
        for (int i = 0; i < GRADE_PERCENTAGE.length; i++) {
            gradeWeight += GRADE_PERCENTAGE[i];
            if (randomGrade < gradeWeight) {
                return QuestGrade.values()[i];
            }
        }
        return QuestGrade.values()[0];
    }
}
