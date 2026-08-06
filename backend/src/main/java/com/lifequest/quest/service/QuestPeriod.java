package com.lifequest.quest.service;

import com.lifequest.quest.domain.QuestCadence;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Objects;

@Service
public class QuestPeriod {
    private final Clock clock;

    public static final int DAY_CHANGE_HOUR = 4;
    public static final LocalTime DAY_CHANGE_OFFSET = LocalTime.of(DAY_CHANGE_HOUR, 0);

    public QuestPeriod(Clock clock) {
        this.clock = clock;
    }

    public LocalDate logicalDate() {
        return LocalDateTime.now(clock).minusHours(DAY_CHANGE_HOUR).toLocalDate();
    }

    public class QuestLifePeriod {
        private final LocalDate startAt;
        private final LocalDateTime expiresAt;

        QuestLifePeriod(QuestCadence cadence) {
            if (Objects.requireNonNull(cadence) == QuestCadence.WEEKLY) {
                LocalDate temp = logicalDate();
                startAt = temp.minusDays(temp.getDayOfWeek().getValue() - 1);
                expiresAt = LocalDateTime.of(
                    startAt.plusDays(7),
                    DAY_CHANGE_OFFSET);
            } else {
                startAt = logicalDate();
                expiresAt = LocalDateTime.of(
                    startAt.plusDays(1),
                    DAY_CHANGE_OFFSET);
            }
        }

        public LocalDate getStartAt() {
            return startAt;
        }

        public LocalDateTime getExpiresAt() {
            return expiresAt;
        }
    }

    public QuestLifePeriod create(QuestCadence cadence) {
        return new QuestLifePeriod(cadence);
    }

    /**
     * 직전 주기의 시작일. 배정에서 "어제(지난주)에 받은 퀘스트"를 후보에서 빼는 데 쓴다
     * (docs/05-business-rules.md §1-B).
     *
     * <p>일간은 하루 전, 주간은 7일 전이다. 두 값 모두 이번 주기 시작일에서 빼므로 주간은
     * 지지난 월요일이 되며, 요일 정렬은 {@link #create}가 이미 끝낸 상태다.
     *
     * <p>이 계산을 호출자에게 넘기지 않는 이유는 {@link #create}와 같다 — 호출부에서
     * {@code LocalDate.now()}를 빼는 형태가 되면 04:00 이전 조회가 하루 어긋나는데,
     * 컴파일도 테스트도 통과하고 매일 같은 시간대에만 조용히 틀린다.
     */
    public LocalDate previousPeriodStart(QuestCadence cadence) {
        LocalDate periodStart = create(cadence).getStartAt();
        return cadence == QuestCadence.WEEKLY
            ? periodStart.minusDays(7)
            : periodStart.minusDays(1);
    }
}

