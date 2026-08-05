package com.lifequest.recommendation;
import com.lifequest.user.User;
import jakarta.persistence.*;
import java.time.*;
@Entity @Table(name="quest_recommendation_daily_usage",uniqueConstraints=@UniqueConstraint(name="uk_recommendation_usage_user_date",columnNames={"user_id","usage_date"}))
public class QuestRecommendationUsage {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="user_id") private User user;
 @Column(name="usage_date",nullable=false) private LocalDate usageDate;
 @Column(name="request_count",nullable=false) private int requestCount;
 @Column(name="updated_at",nullable=false) private LocalDateTime updatedAt;
 protected QuestRecommendationUsage(){} public QuestRecommendationUsage(User user,LocalDate date,LocalDateTime now){this.user=user;this.usageDate=date;this.requestCount=1;this.updatedAt=now;}
 public void increment(LocalDateTime now){requestCount++;updatedAt=now;} public int getRequestCount(){return requestCount;} public LocalDate getUsageDate(){return usageDate;}
}
