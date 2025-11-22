#!/bin/bash

# Script to update all views to use QuickSendBar as sheet presentation

echo "Updating InboxView.swift..."
# Update InboxView ReceivedShareRow
perl -i -pe 's/showShareSheet = !showShareSheet/trackToShare = createMusicItem(); showShareSheet = true/g' apps/ios/phlock/phlock/Views/Main/InboxView.swift

# Update InboxView SentShareRow
perl -i -pe 's/showShareSheet\.toggle\(\)/trackToShare = createMusicItem(); showShareSheet = true/g' apps/ios/phlock/phlock/Views/Main/InboxView.swift

echo "Updating ArtistDetailView.swift..."
# Update ArtistDetailView
perl -i -pe 's/showQuickSendBar\.toggle\(\)/trackToShare = track; showQuickSendBar = true/g' apps/ios/phlock/phlock/Views/Main/ArtistDetailView.swift

echo "Updating SearchResultsView.swift..."
# Update SearchResultsView
perl -i -pe 's/showQuickSendBar = !showQuickSendBar/trackToShare = track; showQuickSendBar = true/g' apps/ios/phlock/phlock/Views/Main/SearchResultsView.swift

echo "Done updating all views!"