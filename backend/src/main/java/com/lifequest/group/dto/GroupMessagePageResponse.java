package com.lifequest.group.dto;
import java.util.List;
public record GroupMessagePageResponse(List<GroupMessageResponse> messages,boolean hasMoreBefore,Long latestId) {}
