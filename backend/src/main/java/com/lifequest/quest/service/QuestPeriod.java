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
}

