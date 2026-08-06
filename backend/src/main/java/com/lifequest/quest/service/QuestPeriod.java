package com.lifequest.quest.service;

import com.lifequest.quest.domain.QuestCadence;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Service
public class QuestPeriod {
    private final Clock clock;

    public final LocalTime DAY_CHANGE_OFFSET = LocalTime.of(4, 0);

    public QuestPeriod(Clock clock) {
        this.clock = clock;
    }

    public record QuestLifePeriod(
        LocalDate startAt,
        LocalDateTime expiresAt
    ) {
    }

    public QuestLifePeriod create(QuestCadence cadence) {
        LocalDate now =  LocalDate.now(clock);
        Integer period = switch (cadence) {
            case DAILY -> 1;
            case WEEKLY -> 7;
        };

        return new QuestLifePeriod(
            now,
            LocalDateTime.of(now.plusDays(period), DAY_CHANGE_OFFSET)
        );
    }
}

